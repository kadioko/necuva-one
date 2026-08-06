create type public.configuration_approval_status as enum ('draft', 'approved', 'retired');

create table public.currencies (
  code char(3) primary key check (code ~ '^[A-Z]{3}$'),
  name text not null check (char_length(trim(name)) between 1 and 100),
  symbol text not null check (char_length(trim(symbol)) between 1 and 12),
  decimal_places smallint not null default 2 check (decimal_places between 0 and 4),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger currencies_set_updated_at before update on public.currencies for each row execute function private.set_updated_at();
insert into public.currencies (code, name, symbol, decimal_places) values ('TZS', 'Tanzanian shilling', 'TZS', 0) on conflict (code) do nothing;

create table public.organisation_exchange_rate_versions (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  currency_code char(3) not null references public.currencies(code) on delete restrict,
  effective_on date not null,
  rate numeric(20,10) not null check (rate > 0),
  source_reference text not null check (char_length(trim(source_reference)) between 3 and 500),
  version integer not null check (version > 0),
  approval_status public.configuration_approval_status not null default 'draft',
  created_by uuid not null references public.profiles(id) on delete restrict,
  approved_by uuid references public.profiles(id) on delete restrict,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (organisation_id, currency_code, effective_on, version),
  check ((approval_status = 'approved' and approved_by is not null and approved_at is not null) or (approval_status <> 'approved' and approved_by is null and approved_at is null))
);
create unique index organisation_exchange_rates_one_approved_idx on public.organisation_exchange_rate_versions (organisation_id, currency_code, effective_on) where approval_status = 'approved';
create index organisation_exchange_rates_effective_idx on public.organisation_exchange_rate_versions (organisation_id, currency_code, effective_on desc, version desc);

create table public.tax_configuration_versions (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  code text not null check (code ~ '^[A-Z0-9_.-]{2,50}$'),
  name text not null check (char_length(trim(name)) between 1 and 150),
  tax_type text not null check (tax_type in ('vat', 'withholding', 'other')),
  rate_percent numeric(9,6) not null check (rate_percent >= 0 and rate_percent <= 100),
  effective_from date not null,
  effective_to date,
  source_reference text not null check (char_length(trim(source_reference)) between 3 and 500),
  version integer not null check (version > 0),
  approval_status public.configuration_approval_status not null default 'draft',
  created_by uuid not null references public.profiles(id) on delete restrict,
  approved_by uuid references public.profiles(id) on delete restrict,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (organisation_id, code, effective_from, version),
  check (effective_to is null or effective_to >= effective_from),
  check ((approval_status = 'approved' and approved_by is not null and approved_at is not null) or (approval_status <> 'approved' and approved_by is null and approved_at is null))
);
create unique index tax_configurations_one_approved_idx on public.tax_configuration_versions (organisation_id, code, effective_from) where approval_status = 'approved';
create index tax_configurations_effective_idx on public.tax_configuration_versions (organisation_id, code, effective_from desc, version desc);

alter table public.currencies enable row level security;
alter table public.currencies force row level security;
alter table public.organisation_exchange_rate_versions enable row level security;
alter table public.organisation_exchange_rate_versions force row level security;
alter table public.tax_configuration_versions enable row level security;
alter table public.tax_configuration_versions force row level security;
grant select on public.currencies, public.organisation_exchange_rate_versions, public.tax_configuration_versions to authenticated;
create policy currencies_authenticated_select on public.currencies for select using (auth.uid() is not null);
create policy organisation_exchange_rates_member_select on public.organisation_exchange_rate_versions for select using (private.is_active_organisation_member(organisation_id));
create policy tax_configurations_member_select on public.tax_configuration_versions for select using (private.is_active_organisation_member(organisation_id));

insert into public.permissions (code, module_code, description) values
  ('platform.localisation.manage', 'platform', 'Manage shared currency reference data'),
  ('organisation.localisation.manage', 'platform', 'Create tenant tax and exchange-rate configurations'),
  ('organisation.localisation.approve', 'platform', 'Approve tenant tax and exchange-rate configurations')
on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in ('platform.localisation.manage')
where r.organisation_id is null and r.code = 'platform.owner' on conflict do nothing;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in ('organisation.localisation.manage', 'organisation.localisation.approve')
where r.organisation_id is null and r.code = 'organisation.owner' on conflict do nothing;

create or replace function public.upsert_currency(input jsonb)
returns char(3) language plpgsql security definer set search_path = pg_catalog, public as $$
declare currency_code char(3) := upper(nullif(trim(input ->> 'code'), '')); currency_name text := nullif(trim(input ->> 'name'), ''); currency_symbol text := nullif(trim(input ->> 'symbol'), ''); currency_decimals smallint := (input ->> 'decimalPlaces')::smallint; active boolean := coalesce((input ->> 'isActive')::boolean, true);
begin
  if not private.has_platform_permission('platform.localisation.manage') then raise exception 'Platform localisation management permission is required' using errcode = '42501'; end if;
  if currency_code is null or currency_code !~ '^[A-Z]{3}$' or currency_name is null or currency_symbol is null or currency_decimals not between 0 and 4 then raise exception 'Currency input is invalid' using errcode = '22023'; end if;
  insert into public.currencies (code, name, symbol, decimal_places, is_active) values (currency_code, currency_name, currency_symbol, currency_decimals, active) on conflict (code) do update set name=excluded.name, symbol=excluded.symbol, decimal_places=excluded.decimal_places, is_active=excluded.is_active;
  insert into public.audit_events (actor_user_id, action, entity_type, after_state) values (auth.uid(), 'currency_upserted', 'currency', input);
  return currency_code;
end; $$;

create or replace function public.create_exchange_rate_version(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; target_currency_code char(3) := upper(nullif(trim(input ->> 'currencyCode'), '')); target_effective_date date := (input ->> 'effectiveOn')::date; exchange_rate numeric(20,10) := (input ->> 'rate')::numeric; source text := nullif(trim(input ->> 'sourceReference'), ''); next_version integer; result_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.localisation.manage') then raise exception 'Organisation localisation management permission is required' using errcode='42501'; end if;
  if target_currency_code is null or target_effective_date is null or exchange_rate is null or exchange_rate <= 0 or source is null or not exists (select 1 from public.currencies where code=target_currency_code and is_active) then raise exception 'Exchange rate input is invalid' using errcode='22023'; end if;
  if exists (select 1 from public.organisations where id=org_id and default_currency_code=target_currency_code) then raise exception 'An exchange rate is not required for the organisation base currency' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtext(org_id::text || target_currency_code || target_effective_date::text));
  select coalesce(max(version),0)+1 into next_version from public.organisation_exchange_rate_versions where organisation_id=org_id and currency_code=target_currency_code and effective_on=target_effective_date;
  insert into public.organisation_exchange_rate_versions (organisation_id,currency_code,effective_on,rate,source_reference,version,created_by) values (org_id,target_currency_code,target_effective_date,exchange_rate,source,next_version,auth.uid()) returning id into result_id;
  insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (org_id,auth.uid(),'exchange_rate_version_created','exchange_rate_version',result_id,input);
  return result_id;
end; $$;

create or replace function public.approve_exchange_rate_version(target_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare rate_record public.organisation_exchange_rate_versions%rowtype;
begin
  select * into rate_record from public.organisation_exchange_rate_versions where id=target_id for update;
  if rate_record.id is null or not private.has_organisation_permission(rate_record.organisation_id, 'organisation.localisation.approve') or rate_record.approval_status <> 'draft' then raise exception 'Exchange rate version cannot be approved' using errcode='42501'; end if;
  update public.organisation_exchange_rate_versions set approval_status='retired' where organisation_id=rate_record.organisation_id and currency_code=rate_record.currency_code and effective_on=rate_record.effective_on and approval_status='approved';
  update public.organisation_exchange_rate_versions set approval_status='approved', approved_by=auth.uid(), approved_at=now() where id=target_id;
  insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id) values (rate_record.organisation_id,auth.uid(),'exchange_rate_version_approved','exchange_rate_version',target_id);
end; $$;

create or replace function public.create_tax_configuration_version(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; target_tax_code text := upper(nullif(trim(input ->> 'code'), '')); tax_name text := nullif(trim(input ->> 'name'), ''); kind text := input ->> 'taxType'; percent numeric(9,6) := (input ->> 'ratePercent')::numeric; starts_on date := (input ->> 'effectiveFrom')::date; ends_on date := nullif(input ->> 'effectiveTo','')::date; source text := nullif(trim(input ->> 'sourceReference'), ''); next_version integer; result_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.localisation.manage') then raise exception 'Organisation localisation management permission is required' using errcode='42501'; end if;
  if target_tax_code is null or target_tax_code !~ '^[A-Z0-9_.-]{2,50}$' or tax_name is null or kind not in ('vat','withholding','other') or percent is null or percent < 0 or percent > 100 or starts_on is null or (ends_on is not null and ends_on < starts_on) or source is null then raise exception 'Tax configuration input is invalid' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtext(org_id::text || target_tax_code || starts_on::text));
  select coalesce(max(version),0)+1 into next_version from public.tax_configuration_versions where organisation_id=org_id and code=target_tax_code and effective_from=starts_on;
  insert into public.tax_configuration_versions (organisation_id,code,name,tax_type,rate_percent,effective_from,effective_to,source_reference,version,created_by) values (org_id,target_tax_code,tax_name,kind,percent,starts_on,ends_on,source,next_version,auth.uid()) returning id into result_id;
  insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (org_id,auth.uid(),'tax_configuration_version_created','tax_configuration_version',result_id,input);
  return result_id;
end; $$;

create or replace function public.approve_tax_configuration_version(target_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare tax_record public.tax_configuration_versions%rowtype;
begin
  select * into tax_record from public.tax_configuration_versions where id=target_id for update;
  if tax_record.id is null or not private.has_organisation_permission(tax_record.organisation_id, 'organisation.localisation.approve') or tax_record.approval_status <> 'draft' then raise exception 'Tax configuration version cannot be approved' using errcode='42501'; end if;
  update public.tax_configuration_versions set approval_status='retired' where organisation_id=tax_record.organisation_id and code=tax_record.code and effective_from=tax_record.effective_from and approval_status='approved';
  update public.tax_configuration_versions set approval_status='approved', approved_by=auth.uid(), approved_at=now() where id=target_id;
  insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id) values (tax_record.organisation_id,auth.uid(),'tax_configuration_version_approved','tax_configuration_version',target_id);
end; $$;

create or replace function public.create_custom_role(input jsonb) returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; role_code text := lower(nullif(trim(input ->> 'code'), '')); role_name text := nullif(trim(input ->> 'name'), ''); role_scope public.scope_type := (input ->> 'defaultScope')::public.scope_type; permission_codes text[] := array(select jsonb_array_elements_text(coalesce(input -> 'permissionCodes','[]'::jsonb))); role_id uuid;
begin
 if not private.has_organisation_permission(org_id,'organisation.roles.manage') then raise exception 'Organisation role management permission is required' using errcode='42501'; end if;
 if role_code is null or role_code !~ '^[a-z0-9_.-]{3,100}$' or role_name is null or role_scope not in ('organisation','company','branch','warehouse') or cardinality(permission_codes)=0 then raise exception 'Custom role input is invalid' using errcode='22023'; end if;
 if exists (select 1 from public.roles where organisation_id is null and code=role_code) then raise exception 'Custom role code conflicts with a system role' using errcode='23505'; end if;
 if exists (select 1 from unnest(permission_codes) code where code not in ('organisation.structure.manage','organisation.memberships.manage','organisation.audit.read','organisation.support_access.manage','organisation.localisation.manage','organisation.localisation.approve')) then raise exception 'Custom role contains unsupported permission' using errcode='22023'; end if;
 insert into public.roles (organisation_id,code,name,default_scope,is_system) values (org_id,role_code,role_name,role_scope,false) returning id into role_id;
 insert into public.role_permissions (role_id,permission_id) select role_id,id from public.permissions where code=any(permission_codes);
 insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (org_id,auth.uid(),'custom_role_created','role',role_id,input); return role_id;
end; $$;

revoke all on function public.upsert_currency(jsonb), public.create_exchange_rate_version(jsonb), public.approve_exchange_rate_version(uuid), public.create_tax_configuration_version(jsonb), public.approve_tax_configuration_version(uuid) from public;
grant execute on function public.upsert_currency(jsonb), public.create_exchange_rate_version(jsonb), public.approve_exchange_rate_version(uuid), public.create_tax_configuration_version(jsonb), public.approve_tax_configuration_version(uuid) to authenticated;
