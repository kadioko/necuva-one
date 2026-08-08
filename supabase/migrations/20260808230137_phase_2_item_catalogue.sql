create type public.catalog_item_type as enum ('product', 'service');
create type public.unit_dimension as enum ('count', 'weight', 'volume', 'length', 'area', 'time', 'other');
create type public.barcode_symbology as enum ('ean_13', 'ean_8', 'upc_a', 'code_128', 'qr_code', 'other');

create table public.item_categories (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  parent_category_id uuid,
  code text not null check (code ~ '^[A-Z0-9_.-]{2,50}$'),
  name text not null check (char_length(trim(name)) between 1 and 150),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (parent_category_id, organisation_id) references public.item_categories(id, organisation_id) on delete restrict,
  unique (organisation_id, code),
  unique (id, organisation_id)
);

create table public.units_of_measure (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  code text not null check (code ~ '^[A-Z0-9_.-]{1,20}$'),
  name text not null check (char_length(trim(name)) between 1 and 100),
  dimension public.unit_dimension not null,
  decimal_places smallint not null default 0 check (decimal_places between 0 and 6),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organisation_id, code),
  unique (id, organisation_id)
);

create table public.unit_conversions (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  from_unit_id uuid not null,
  to_unit_id uuid not null,
  factor numeric(24,12) not null check (factor > 0),
  created_at timestamptz not null default now(),
  foreign key (from_unit_id, organisation_id) references public.units_of_measure(id, organisation_id) on delete restrict,
  foreign key (to_unit_id, organisation_id) references public.units_of_measure(id, organisation_id) on delete restrict,
  check (from_unit_id <> to_unit_id),
  unique (organisation_id, from_unit_id, to_unit_id)
);

create table public.catalog_items (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  category_id uuid,
  base_unit_id uuid not null,
  item_type public.catalog_item_type not null,
  code text not null check (code ~ '^[A-Z0-9_.-]{2,50}$'),
  name text not null check (char_length(trim(name)) between 1 and 200),
  description text,
  tracks_inventory boolean not null default false,
  is_active boolean not null default true,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (category_id, organisation_id) references public.item_categories(id, organisation_id) on delete restrict,
  foreign key (base_unit_id, organisation_id) references public.units_of_measure(id, organisation_id) on delete restrict,
  check (item_type = 'product' or tracks_inventory = false),
  unique (organisation_id, code),
  unique (id, organisation_id)
);
create index catalog_items_organisation_type_idx on public.catalog_items (organisation_id, item_type, name);

create table public.catalog_item_barcodes (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  item_id uuid not null,
  barcode text not null check (char_length(trim(barcode)) between 3 and 100),
  symbology public.barcode_symbology not null default 'other',
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  foreign key (item_id, organisation_id) references public.catalog_items(id, organisation_id) on delete cascade,
  unique (organisation_id, barcode)
);
create unique index catalog_item_barcodes_primary_idx on public.catalog_item_barcodes (item_id) where is_primary;

create trigger item_categories_set_updated_at before update on public.item_categories for each row execute function private.set_updated_at();
create trigger units_of_measure_set_updated_at before update on public.units_of_measure for each row execute function private.set_updated_at();
create trigger catalog_items_set_updated_at before update on public.catalog_items for each row execute function private.set_updated_at();

alter table public.item_categories enable row level security;
alter table public.item_categories force row level security;
alter table public.units_of_measure enable row level security;
alter table public.units_of_measure force row level security;
alter table public.unit_conversions enable row level security;
alter table public.unit_conversions force row level security;
alter table public.catalog_items enable row level security;
alter table public.catalog_items force row level security;
alter table public.catalog_item_barcodes enable row level security;
alter table public.catalog_item_barcodes force row level security;
grant select on public.item_categories, public.units_of_measure, public.unit_conversions, public.catalog_items, public.catalog_item_barcodes to authenticated;
create policy item_categories_member_select on public.item_categories for select using (private.is_active_organisation_member(organisation_id));
create policy units_of_measure_member_select on public.units_of_measure for select using (private.is_active_organisation_member(organisation_id));
create policy unit_conversions_member_select on public.unit_conversions for select using (private.is_active_organisation_member(organisation_id));
create policy catalog_items_member_select on public.catalog_items for select using (private.is_active_organisation_member(organisation_id));
create policy catalog_item_barcodes_member_select on public.catalog_item_barcodes for select using (private.is_active_organisation_member(organisation_id));

insert into public.permissions (code, module_code, description) values
  ('organisation.catalog.manage', 'platform', 'Manage organisation product and service catalogue')
on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code = 'organisation.catalog.manage'
where r.organisation_id is null and r.code = 'organisation.owner' on conflict do nothing;

create or replace function public.create_item_category(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; parent_id uuid := nullif(input ->> 'parentCategoryId', '')::uuid; category_code text := upper(nullif(trim(input ->> 'code'), '')); category_name text := nullif(trim(input ->> 'name'), ''); result_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.catalog.manage') then raise exception 'Organisation catalogue management permission is required' using errcode='42501'; end if;
  if category_code is null or category_name is null or (parent_id is not null and not exists (select 1 from public.item_categories where id=parent_id and organisation_id=org_id and is_active)) then raise exception 'Item category input is invalid' using errcode='22023'; end if;
  insert into public.item_categories (organisation_id, parent_category_id, code, name) values (org_id, parent_id, category_code, category_name) returning id into result_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'item_category_created', 'item_category', result_id, input);
  return result_id;
end; $$;

create or replace function public.create_unit_of_measure(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; unit_code text := upper(nullif(trim(input ->> 'code'), '')); unit_name text := nullif(trim(input ->> 'name'), ''); unit_kind public.unit_dimension := (input ->> 'dimension')::public.unit_dimension; places smallint := (input ->> 'decimalPlaces')::smallint; result_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.catalog.manage') then raise exception 'Organisation catalogue management permission is required' using errcode='42501'; end if;
  if unit_code is null or unit_name is null or unit_kind is null or places not between 0 and 6 then raise exception 'Unit of measure input is invalid' using errcode='22023'; end if;
  insert into public.units_of_measure (organisation_id, code, name, dimension, decimal_places) values (org_id, unit_code, unit_name, unit_kind, places) returning id into result_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'unit_of_measure_created', 'unit_of_measure', result_id, input);
  return result_id;
end; $$;

create or replace function public.create_unit_conversion(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; source_id uuid := (input ->> 'fromUnitId')::uuid; destination_id uuid := (input ->> 'toUnitId')::uuid; conversion_factor numeric(24,12) := (input ->> 'factor')::numeric; source_dimension public.unit_dimension; destination_dimension public.unit_dimension; result_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.catalog.manage') then raise exception 'Organisation catalogue management permission is required' using errcode='42501'; end if;
  select dimension into source_dimension from public.units_of_measure where id=source_id and organisation_id=org_id and is_active;
  select dimension into destination_dimension from public.units_of_measure where id=destination_id and organisation_id=org_id and is_active;
  if source_id = destination_id or conversion_factor is null or conversion_factor <= 0 or source_dimension is null or source_dimension <> destination_dimension then raise exception 'Unit conversion input is invalid' using errcode='22023'; end if;
  insert into public.unit_conversions (organisation_id, from_unit_id, to_unit_id, factor) values (org_id, source_id, destination_id, conversion_factor) returning id into result_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'unit_conversion_created', 'unit_conversion', result_id, input);
  return result_id;
end; $$;

create or replace function public.upsert_catalog_item(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; item_id uuid := nullif(input ->> 'id', '')::uuid; item_category_id uuid := nullif(input ->> 'categoryId', '')::uuid; unit_id uuid := (input ->> 'baseUnitId')::uuid; item_kind public.catalog_item_type := (input ->> 'itemType')::public.catalog_item_type; item_code text := upper(nullif(trim(input ->> 'code'), '')); item_name text := nullif(trim(input ->> 'name'), ''); item_description text := nullif(trim(input ->> 'description'), ''); inventory_tracked boolean := coalesce((input ->> 'tracksInventory')::boolean, false); active boolean := coalesce((input ->> 'isActive')::boolean, true); before_state jsonb; result_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.catalog.manage') then raise exception 'Organisation catalogue management permission is required' using errcode='42501'; end if;
  if item_kind is null or item_code is null or item_name is null or (item_kind='service' and inventory_tracked) or not exists (select 1 from public.units_of_measure where id=unit_id and organisation_id=org_id and is_active) or (item_category_id is not null and not exists (select 1 from public.item_categories where id=item_category_id and organisation_id=org_id and is_active)) then raise exception 'Catalogue item input is invalid' using errcode='22023'; end if;
  if item_id is null then
    insert into public.catalog_items (organisation_id, category_id, base_unit_id, item_type, code, name, description, tracks_inventory, is_active, created_by) values (org_id, item_category_id, unit_id, item_kind, item_code, item_name, item_description, inventory_tracked, active, auth.uid()) returning id into result_id;
    insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'catalog_item_created', 'catalog_item', result_id, input);
  else
    select to_jsonb(item) into before_state from public.catalog_items item where id=item_id and organisation_id=org_id for update;
    if before_state is null then raise exception 'Catalogue item does not exist' using errcode='23503'; end if;
    update public.catalog_items set category_id=item_category_id, base_unit_id=unit_id, item_type=item_kind, code=item_code, name=item_name, description=item_description, tracks_inventory=inventory_tracked, is_active=active where id=item_id returning id into result_id;
    insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, before_state, after_state) values (org_id, auth.uid(), 'catalog_item_updated', 'catalog_item', result_id, before_state, input);
  end if;
  return result_id;
end; $$;

create or replace function public.add_catalog_item_barcode(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; target_item_id uuid := (input ->> 'itemId')::uuid; barcode_value text := nullif(trim(input ->> 'barcode'), ''); barcode_type public.barcode_symbology := coalesce((input ->> 'symbology')::public.barcode_symbology, 'other'); primary_barcode boolean := coalesce((input ->> 'isPrimary')::boolean, false); result_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.catalog.manage') then raise exception 'Organisation catalogue management permission is required' using errcode='42501'; end if;
  if barcode_value is null or not exists (select 1 from public.catalog_items where id=target_item_id and organisation_id=org_id and is_active) then raise exception 'Item barcode input is invalid' using errcode='22023'; end if;
  if primary_barcode then update public.catalog_item_barcodes set is_primary=false where item_id=target_item_id and is_primary; end if;
  insert into public.catalog_item_barcodes (organisation_id, item_id, barcode, symbology, is_primary) values (org_id, target_item_id, barcode_value, barcode_type, primary_barcode) returning id into result_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'catalog_item_barcode_created', 'catalog_item_barcode', result_id, input);
  return result_id;
end; $$;

create or replace function public.create_custom_role(input jsonb) returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; role_code text := lower(nullif(trim(input ->> 'code'), '')); role_name text := nullif(trim(input ->> 'name'), ''); role_scope public.scope_type := (input ->> 'defaultScope')::public.scope_type; permission_codes text[] := array(select jsonb_array_elements_text(coalesce(input -> 'permissionCodes','[]'::jsonb))); role_id uuid;
begin
 if not private.has_organisation_permission(org_id,'organisation.roles.manage') then raise exception 'Organisation role management permission is required' using errcode='42501'; end if;
 if role_code is null or role_code !~ '^[a-z0-9_.-]{3,100}$' or role_name is null or role_scope not in ('organisation','company','branch','warehouse') or cardinality(permission_codes)=0 then raise exception 'Custom role input is invalid' using errcode='22023'; end if;
 if exists (select 1 from public.roles where organisation_id is null and code=role_code) then raise exception 'Custom role code conflicts with a system role' using errcode='23505'; end if;
 if exists (select 1 from unnest(permission_codes) code where code not in ('organisation.structure.manage','organisation.memberships.manage','organisation.audit.read','organisation.support_access.manage','organisation.localisation.manage','organisation.localisation.approve','organisation.parties.manage','organisation.catalog.manage')) then raise exception 'Custom role contains unsupported permission' using errcode='22023'; end if;
 insert into public.roles (organisation_id,code,name,default_scope,is_system) values (org_id,role_code,role_name,role_scope,false) returning id into role_id;
 insert into public.role_permissions (role_id,permission_id) select role_id,id from public.permissions where code=any(permission_codes);
 insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (org_id,auth.uid(),'custom_role_created','role',role_id,input); return role_id;
end; $$;

revoke all on function public.create_item_category(jsonb), public.create_unit_of_measure(jsonb), public.create_unit_conversion(jsonb), public.upsert_catalog_item(jsonb), public.add_catalog_item_barcode(jsonb) from public;
grant execute on function public.create_item_category(jsonb), public.create_unit_of_measure(jsonb), public.create_unit_conversion(jsonb), public.upsert_catalog_item(jsonb), public.add_catalog_item_barcode(jsonb) to authenticated;
