create type public.master_data_import_type as enum ('business_parties', 'catalog_items');
create type public.master_data_import_status as enum ('staged', 'confirmed');
create type public.master_data_import_operation as enum ('create', 'update', 'invalid');

create table public.master_data_imports (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  import_type public.master_data_import_type not null,
  file_name text not null check (char_length(trim(file_name)) between 1 and 255),
  file_checksum char(64) not null check (file_checksum ~ '^[a-f0-9]{64}$'),
  status public.master_data_import_status not null default 'staged',
  total_rows integer not null check (total_rows between 1 and 500),
  create_rows integer not null default 0 check (create_rows >= 0),
  update_rows integer not null default 0 check (update_rows >= 0),
  invalid_rows integer not null default 0 check (invalid_rows >= 0),
  created_by uuid not null references public.profiles(id) on delete restrict,
  confirmed_by uuid references public.profiles(id) on delete restrict,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (create_rows + update_rows + invalid_rows = total_rows),
  check ((status = 'confirmed' and confirmed_by is not null and confirmed_at is not null) or (status = 'staged' and confirmed_by is null and confirmed_at is null)),
  unique (organisation_id, import_type, file_checksum),
  unique (id, organisation_id)
);

create table public.master_data_import_rows (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  import_id uuid not null,
  row_number integer not null check (row_number >= 2),
  operation public.master_data_import_operation not null,
  raw_data jsonb not null,
  normalized_data jsonb not null,
  validation_errors text[] not null default '{}',
  created_at timestamptz not null default now(),
  foreign key (import_id, organisation_id) references public.master_data_imports(id, organisation_id) on delete cascade,
  check ((operation = 'invalid' and cardinality(validation_errors) > 0) or (operation <> 'invalid' and cardinality(validation_errors) = 0)),
  unique (import_id, row_number)
);
create index master_data_imports_organisation_created_idx on public.master_data_imports (organisation_id, created_at desc);
create index master_data_import_rows_import_operation_idx on public.master_data_import_rows (import_id, operation, row_number);
create trigger master_data_imports_set_updated_at before update on public.master_data_imports for each row execute function private.set_updated_at();

insert into public.permissions (code, module_code, description) values
  ('organisation.imports.manage', 'platform', 'Stage, preview, and confirm controlled master-data imports')
on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code = 'organisation.imports.manage'
where r.organisation_id is null and r.code = 'organisation.owner' on conflict do nothing;

alter table public.master_data_imports enable row level security;
alter table public.master_data_imports force row level security;
alter table public.master_data_import_rows enable row level security;
alter table public.master_data_import_rows force row level security;
grant select on public.master_data_imports, public.master_data_import_rows to authenticated;
create policy master_data_imports_authorised_select on public.master_data_imports for select using (private.has_organisation_permission(organisation_id, 'organisation.imports.manage'));
create policy master_data_import_rows_authorised_select on public.master_data_import_rows for select using (private.has_organisation_permission(organisation_id, 'organisation.imports.manage'));

create or replace function public.stage_master_data_import(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  org_id uuid := (input ->> 'organisationId')::uuid;
  target_type public.master_data_import_type := (input ->> 'importType')::public.master_data_import_type;
  source_name text := nullif(trim(input ->> 'fileName'), '');
  source_checksum text := lower(nullif(trim(input ->> 'fileChecksum'), ''));
  source_rows jsonb := input -> 'rows';
  batch_id uuid;
  row_record jsonb;
  row_data jsonb;
  row_errors text[];
  row_operation public.master_data_import_operation;
  normalized jsonb;
  seen_keys text[] := '{}';
  business_key text;
  existing_id uuid;
  target_unit_id uuid;
  target_category_id uuid;
  party_kind text;
  item_kind text;
  active_text text;
  tracked_text text;
  create_count integer := 0;
  update_count integer := 0;
  invalid_count integer := 0;
  processed_count integer := 0;
  source_count integer;
  source_row_number integer;
begin
  if not private.has_organisation_permission(org_id, 'organisation.imports.manage') then raise exception 'Organisation import management permission is required' using errcode='42501'; end if;
  if target_type = 'business_parties' and not private.has_organisation_permission(org_id, 'organisation.parties.manage') then raise exception 'Organisation party management permission is required' using errcode='42501'; end if;
  if target_type = 'catalog_items' and not private.has_organisation_permission(org_id, 'organisation.catalog.manage') then raise exception 'Organisation catalogue management permission is required' using errcode='42501'; end if;
  if source_name is null or char_length(source_name) > 255 or source_checksum is null or source_checksum !~ '^[a-f0-9]{64}$' or source_rows is null or jsonb_typeof(source_rows) <> 'array' then raise exception 'Import metadata is invalid' using errcode='22023'; end if;
  source_count := jsonb_array_length(source_rows);
  if source_count not between 1 and 500 then raise exception 'Import must contain between 1 and 500 rows' using errcode='22023'; end if;

  insert into public.master_data_imports (organisation_id, import_type, file_name, file_checksum, total_rows, invalid_rows, created_by)
  values (org_id, target_type, source_name, source_checksum, source_count, source_count, auth.uid()) returning id into batch_id;

  for row_record in select value from jsonb_array_elements(source_rows) loop
    processed_count := processed_count + 1;
    row_data := coalesce(row_record -> 'data', '{}'::jsonb);
    row_errors := '{}';
    existing_id := null;
    target_unit_id := null;
    target_category_id := null;

    if coalesce(row_record ->> 'rowNumber', '') !~ '^[0-9]+$' then source_row_number := processed_count + 1; row_errors := array_append(row_errors, 'Row number is invalid.');
    else source_row_number := (row_record ->> 'rowNumber')::integer; if source_row_number < 2 then row_errors := array_append(row_errors, 'Row number is invalid.'); end if;
    end if;

    if target_type = 'business_parties' then
      business_key := upper(nullif(trim(row_data ->> 'externalCode'), ''));
      party_kind := lower(nullif(trim(row_data ->> 'partyType'), ''));
      active_text := lower(coalesce(nullif(trim(row_data ->> 'isActive'), ''), 'true'));
      if business_key is null or business_key !~ '^[A-Z0-9_.-]{2,50}$' then row_errors := array_append(row_errors, 'External code must contain 2-50 letters, numbers, dots, hyphens, or underscores.'); end if;
      if nullif(trim(row_data ->> 'displayName'), '') is null or char_length(trim(row_data ->> 'displayName')) > 200 then row_errors := array_append(row_errors, 'Display name is required and may not exceed 200 characters.'); end if;
      if party_kind is null or party_kind not in ('customer', 'supplier', 'both') then row_errors := array_append(row_errors, 'Party type must be customer, supplier, or both.'); end if;
      if active_text not in ('true', 'false') then row_errors := array_append(row_errors, 'Active must be true or false.'); end if;
      if nullif(trim(row_data ->> 'email'), '') is not null and (char_length(trim(row_data ->> 'email')) > 254 or trim(row_data ->> 'email') !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') then row_errors := array_append(row_errors, 'Email address is invalid.'); end if;
      if char_length(coalesce(trim(row_data ->> 'legalName'), '')) > 250 or char_length(coalesce(trim(row_data ->> 'taxIdentificationNumber'), '')) > 100 or char_length(coalesce(trim(row_data ->> 'phone'), '')) > 50 then row_errors := array_append(row_errors, 'An optional party field exceeds its maximum length.'); end if;
      normalized := jsonb_build_object('externalCode', business_key, 'displayName', nullif(trim(row_data ->> 'displayName'), ''), 'partyType', party_kind, 'legalName', nullif(trim(row_data ->> 'legalName'), ''), 'taxIdentificationNumber', nullif(trim(row_data ->> 'taxIdentificationNumber'), ''), 'email', lower(nullif(trim(row_data ->> 'email'), '')), 'phone', nullif(trim(row_data ->> 'phone'), ''), 'isActive', active_text);
      if business_key is not null and business_key = any(seen_keys) then row_errors := array_append(row_errors, 'External code is duplicated within this file.'); elsif business_key is not null then seen_keys := array_append(seen_keys, business_key); end if;
      select id into existing_id from public.business_parties where organisation_id=org_id and external_code=business_key;
    else
      business_key := upper(nullif(trim(row_data ->> 'code'), ''));
      item_kind := lower(nullif(trim(row_data ->> 'itemType'), ''));
      active_text := lower(coalesce(nullif(trim(row_data ->> 'isActive'), ''), 'true'));
      tracked_text := lower(coalesce(nullif(trim(row_data ->> 'tracksInventory'), ''), 'false'));
      if business_key is null or business_key !~ '^[A-Z0-9_.-]{2,50}$' then row_errors := array_append(row_errors, 'Item code must contain 2-50 letters, numbers, dots, hyphens, or underscores.'); end if;
      if nullif(trim(row_data ->> 'name'), '') is null or char_length(trim(row_data ->> 'name')) > 200 then row_errors := array_append(row_errors, 'Item name is required and may not exceed 200 characters.'); end if;
      if item_kind is null or item_kind not in ('product', 'service') then row_errors := array_append(row_errors, 'Item type must be product or service.'); end if;
      if active_text not in ('true', 'false') or tracked_text not in ('true', 'false') then row_errors := array_append(row_errors, 'Active and tracks inventory must be true or false.'); end if;
      if item_kind = 'service' and tracked_text = 'true' then row_errors := array_append(row_errors, 'Services cannot track inventory.'); end if;
      if char_length(coalesce(trim(row_data ->> 'description'), '')) > 2000 then row_errors := array_append(row_errors, 'Description may not exceed 2000 characters.'); end if;
      select id into target_unit_id from public.units_of_measure where organisation_id=org_id and code=upper(nullif(trim(row_data ->> 'baseUnitCode'), '')) and is_active;
      if target_unit_id is null then row_errors := array_append(row_errors, 'Base unit code does not match an active unit.'); end if;
      if nullif(trim(row_data ->> 'categoryCode'), '') is not null then
        select id into target_category_id from public.item_categories where organisation_id=org_id and code=upper(trim(row_data ->> 'categoryCode')) and is_active;
        if target_category_id is null then row_errors := array_append(row_errors, 'Category code does not match an active category.'); end if;
      end if;
      normalized := jsonb_build_object('code', business_key, 'name', nullif(trim(row_data ->> 'name'), ''), 'itemType', item_kind, 'baseUnitId', target_unit_id, 'categoryId', target_category_id, 'description', nullif(trim(row_data ->> 'description'), ''), 'tracksInventory', tracked_text, 'isActive', active_text);
      if business_key is not null and business_key = any(seen_keys) then row_errors := array_append(row_errors, 'Item code is duplicated within this file.'); elsif business_key is not null then seen_keys := array_append(seen_keys, business_key); end if;
      select id into existing_id from public.catalog_items where organisation_id=org_id and code=business_key;
    end if;

    if cardinality(row_errors) > 0 then row_operation := 'invalid'; invalid_count := invalid_count + 1;
    elsif existing_id is not null then row_operation := 'update'; update_count := update_count + 1; normalized := normalized || jsonb_build_object('id', existing_id);
    else row_operation := 'create'; create_count := create_count + 1;
    end if;
    insert into public.master_data_import_rows (organisation_id, import_id, row_number, operation, raw_data, normalized_data, validation_errors)
    values (org_id, batch_id, source_row_number, row_operation, row_data, normalized, row_errors);
  end loop;

  update public.master_data_imports set create_rows=create_count, update_rows=update_count, invalid_rows=invalid_count where id=batch_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'master_data_import_staged', 'master_data_import', batch_id, jsonb_build_object('importType', target_type, 'fileName', source_name, 'fileChecksum', source_checksum, 'totalRows', source_count, 'createRows', create_count, 'updateRows', update_count, 'invalidRows', invalid_count));
  return batch_id;
end; $$;

create or replace function public.confirm_master_data_import(target_id uuid)
returns integer language plpgsql security definer set search_path = pg_catalog, public as $$
declare batch public.master_data_imports%rowtype; staged_row record; applied_count integer := 0;
begin
  select * into batch from public.master_data_imports where id=target_id for update;
  if batch.id is null or not private.has_organisation_permission(batch.organisation_id, 'organisation.imports.manage') then raise exception 'Organisation import management permission is required' using errcode='42501'; end if;
  if batch.import_type = 'business_parties' and not private.has_organisation_permission(batch.organisation_id, 'organisation.parties.manage') then raise exception 'Organisation party management permission is required' using errcode='42501'; end if;
  if batch.import_type = 'catalog_items' and not private.has_organisation_permission(batch.organisation_id, 'organisation.catalog.manage') then raise exception 'Organisation catalogue management permission is required' using errcode='42501'; end if;
  if batch.status <> 'staged' or batch.invalid_rows > 0 then raise exception 'Only a valid staged import can be confirmed' using errcode='22023'; end if;
  for staged_row in select normalized_data from public.master_data_import_rows where import_id=target_id order by row_number loop
    if batch.import_type = 'business_parties' then perform public.upsert_business_party(staged_row.normalized_data || jsonb_build_object('organisationId', batch.organisation_id));
    else perform public.upsert_catalog_item(staged_row.normalized_data || jsonb_build_object('organisationId', batch.organisation_id));
    end if;
    applied_count := applied_count + 1;
  end loop;
  if applied_count <> batch.total_rows then raise exception 'Import row count changed before confirmation' using errcode='40001'; end if;
  update public.master_data_imports set status='confirmed', confirmed_by=auth.uid(), confirmed_at=now() where id=target_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (batch.organisation_id, auth.uid(), 'master_data_import_confirmed', 'master_data_import', target_id, jsonb_build_object('importType', batch.import_type, 'totalRows', batch.total_rows, 'createRows', batch.create_rows, 'updateRows', batch.update_rows));
  return applied_count;
end; $$;

create or replace function public.create_custom_role(input jsonb) returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; role_code text := lower(nullif(trim(input ->> 'code'), '')); role_name text := nullif(trim(input ->> 'name'), ''); role_scope public.scope_type := (input ->> 'defaultScope')::public.scope_type; permission_codes text[] := array(select jsonb_array_elements_text(coalesce(input -> 'permissionCodes','[]'::jsonb))); role_id uuid;
begin
 if not private.has_organisation_permission(org_id,'organisation.roles.manage') then raise exception 'Organisation role management permission is required' using errcode='42501'; end if;
 if role_code is null or role_code !~ '^[a-z0-9_.-]{3,100}$' or role_name is null or role_scope not in ('organisation','company','branch','warehouse') or cardinality(permission_codes)=0 then raise exception 'Custom role input is invalid' using errcode='22023'; end if;
 if exists (select 1 from public.roles where organisation_id is null and code=role_code) then raise exception 'Custom role code conflicts with a system role' using errcode='23505'; end if;
 if exists (select 1 from unnest(permission_codes) code where code not in ('organisation.structure.manage','organisation.memberships.manage','organisation.audit.read','organisation.support_access.manage','organisation.localisation.manage','organisation.localisation.approve','organisation.parties.manage','organisation.catalog.manage','organisation.payment_references.manage','organisation.imports.manage')) then raise exception 'Custom role contains unsupported permission' using errcode='22023'; end if;
 insert into public.roles (organisation_id,code,name,default_scope,is_system) values (org_id,role_code,role_name,role_scope,false) returning id into role_id;
 insert into public.role_permissions (role_id,permission_id) select role_id,id from public.permissions where code=any(permission_codes);
 insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (org_id,auth.uid(),'custom_role_created','role',role_id,input); return role_id;
end; $$;

revoke all on function public.stage_master_data_import(jsonb), public.confirm_master_data_import(uuid) from public;
grant execute on function public.stage_master_data_import(jsonb), public.confirm_master_data_import(uuid) to authenticated;
