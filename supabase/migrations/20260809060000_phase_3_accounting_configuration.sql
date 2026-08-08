create type public.account_type as enum ('asset', 'liability', 'equity', 'income', 'expense');
create type public.account_normal_balance as enum ('debit', 'credit');
create type public.fiscal_year_status as enum ('draft', 'open', 'closed');
create type public.fiscal_period_status as enum ('future', 'open', 'closed');

create table public.account_groups (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  company_id uuid not null,
  parent_group_id uuid,
  code text not null check (code ~ '^[A-Z0-9.-]{2,30}$'),
  name text not null check (char_length(trim(name)) between 1 and 150),
  account_type public.account_type not null,
  description text check (description is null or char_length(trim(description)) <= 500),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (company_id, organisation_id) references public.companies(id, organisation_id) on delete restrict,
  foreign key (parent_group_id, organisation_id, company_id, account_type) references public.account_groups(id, organisation_id, company_id, account_type) on delete restrict,
  check (parent_group_id is null or parent_group_id <> id),
  unique (organisation_id, company_id, code),
  unique (id, organisation_id, company_id),
  unique (id, organisation_id, company_id, account_type)
);

create table public.chart_accounts (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  company_id uuid not null,
  group_id uuid not null,
  code text not null check (code ~ '^[A-Z0-9.-]{2,30}$'),
  name text not null check (char_length(trim(name)) between 1 and 150),
  account_type public.account_type not null,
  normal_balance public.account_normal_balance generated always as (
    case when account_type in ('asset', 'expense') then 'debit'::public.account_normal_balance else 'credit'::public.account_normal_balance end
  ) stored,
  description text check (description is null or char_length(trim(description)) <= 500),
  is_control_account boolean not null default false,
  allow_manual_posting boolean not null default true,
  is_active boolean not null default true,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (company_id, organisation_id) references public.companies(id, organisation_id) on delete restrict,
  foreign key (group_id, organisation_id, company_id, account_type) references public.account_groups(id, organisation_id, company_id, account_type) on delete restrict,
  check (not is_control_account or not allow_manual_posting),
  unique (organisation_id, company_id, code),
  unique (id, organisation_id, company_id)
);
create index chart_accounts_company_type_code_idx on public.chart_accounts (company_id, account_type, code);

create table public.fiscal_years (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  company_id uuid not null,
  name text not null check (char_length(trim(name)) between 2 and 100),
  start_date date not null,
  end_date date not null,
  status public.fiscal_year_status not null default 'draft',
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (company_id, organisation_id) references public.companies(id, organisation_id) on delete restrict,
  check (extract(day from start_date) = 1),
  check (end_date = (start_date + interval '1 year - 1 day')::date),
  unique (organisation_id, company_id, name),
  unique (organisation_id, company_id, start_date),
  unique (id, organisation_id, company_id)
);

create table public.fiscal_periods (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  company_id uuid not null,
  fiscal_year_id uuid not null,
  period_number smallint not null check (period_number between 1 and 12),
  name text not null check (char_length(trim(name)) between 2 and 100),
  start_date date not null,
  end_date date not null,
  status public.fiscal_period_status not null default 'future',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (fiscal_year_id, organisation_id, company_id) references public.fiscal_years(id, organisation_id, company_id) on delete cascade,
  check (end_date >= start_date),
  unique (fiscal_year_id, period_number),
  unique (fiscal_year_id, start_date),
  unique (id, organisation_id, company_id)
);

create or replace function private.enforce_fiscal_year_dates()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if exists (select 1 from public.fiscal_years y where y.company_id=new.company_id and y.id<>new.id and daterange(y.start_date, y.end_date, '[]') && daterange(new.start_date, new.end_date, '[]')) then
    raise exception 'Fiscal years cannot overlap for a company' using errcode='23P01';
  end if;
  return new;
end; $$;

create or replace function private.enforce_fiscal_period_dates()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare year_start date; year_end date;
begin
  select start_date, end_date into year_start, year_end from public.fiscal_years where id=new.fiscal_year_id and organisation_id=new.organisation_id and company_id=new.company_id;
  if year_start is null or new.start_date < year_start or new.end_date > year_end then raise exception 'Fiscal period must fall within its fiscal year' using errcode='23514'; end if;
  if exists (select 1 from public.fiscal_periods p where p.fiscal_year_id=new.fiscal_year_id and p.id<>new.id and daterange(p.start_date, p.end_date, '[]') && daterange(new.start_date, new.end_date, '[]')) then raise exception 'Fiscal periods cannot overlap' using errcode='23P01'; end if;
  return new;
end; $$;

create trigger fiscal_years_dates_guard before insert or update on public.fiscal_years for each row execute function private.enforce_fiscal_year_dates();
create trigger fiscal_periods_dates_guard before insert or update on public.fiscal_periods for each row execute function private.enforce_fiscal_period_dates();
create trigger account_groups_set_updated_at before update on public.account_groups for each row execute function private.set_updated_at();
create trigger chart_accounts_set_updated_at before update on public.chart_accounts for each row execute function private.set_updated_at();
create trigger fiscal_years_set_updated_at before update on public.fiscal_years for each row execute function private.set_updated_at();
create trigger fiscal_periods_set_updated_at before update on public.fiscal_periods for each row execute function private.set_updated_at();

insert into public.permissions (code, module_code, description) values
  ('organisation.accounting.configure', 'accounting', 'Configure company chart of accounts and fiscal calendars')
on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code = 'organisation.accounting.configure'
where r.organisation_id is null and r.code = 'organisation.owner' on conflict do nothing;

alter table public.account_groups enable row level security;
alter table public.account_groups force row level security;
alter table public.chart_accounts enable row level security;
alter table public.chart_accounts force row level security;
alter table public.fiscal_years enable row level security;
alter table public.fiscal_years force row level security;
alter table public.fiscal_periods enable row level security;
alter table public.fiscal_periods force row level security;
grant select on public.account_groups, public.chart_accounts, public.fiscal_years, public.fiscal_periods to authenticated;
create policy account_groups_authorised_select on public.account_groups for select using (private.has_company_permission(organisation_id, company_id, 'organisation.accounting.configure'));
create policy chart_accounts_authorised_select on public.chart_accounts for select using (private.has_company_permission(organisation_id, company_id, 'organisation.accounting.configure'));
create policy fiscal_years_authorised_select on public.fiscal_years for select using (private.has_company_permission(organisation_id, company_id, 'organisation.accounting.configure'));
create policy fiscal_periods_authorised_select on public.fiscal_periods for select using (private.has_company_permission(organisation_id, company_id, 'organisation.accounting.configure'));

create or replace function public.create_account_group(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; target_company_id uuid := (input ->> 'companyId')::uuid; parent_id uuid := nullif(input ->> 'parentGroupId', '')::uuid; group_code text := upper(nullif(trim(input ->> 'code'), '')); group_name text := nullif(trim(input ->> 'name'), ''); group_type public.account_type := (input ->> 'accountType')::public.account_type; group_description text := nullif(trim(input ->> 'description'), ''); result_id uuid;
begin
  if not private.has_company_permission(org_id, target_company_id, 'organisation.accounting.configure') then raise exception 'Company accounting configuration permission is required' using errcode='42501'; end if;
  if group_code is null or group_code !~ '^[A-Z0-9.-]{2,30}$' or group_name is null or group_type is null or char_length(group_name)>150 or char_length(coalesce(group_description,''))>500 or not exists (select 1 from public.companies where id=target_company_id and organisation_id=org_id and is_active) or (parent_id is not null and not exists (select 1 from public.account_groups where id=parent_id and organisation_id=org_id and company_id=target_company_id and account_type=group_type and is_active)) then raise exception 'Account group input is invalid' using errcode='22023'; end if;
  insert into public.account_groups (organisation_id, company_id, parent_group_id, code, name, account_type, description) values (org_id, target_company_id, parent_id, group_code, group_name, group_type, group_description) returning id into result_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'account_group_created', 'account_group', result_id, jsonb_build_object('companyId', target_company_id, 'parentGroupId', parent_id, 'code', group_code, 'name', group_name, 'accountType', group_type));
  return result_id;
end; $$;

create or replace function public.upsert_chart_account(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; target_company_id uuid := (input ->> 'companyId')::uuid; target_id uuid := nullif(input ->> 'id', '')::uuid; target_group_id uuid := (input ->> 'groupId')::uuid; account_code text := upper(nullif(trim(input ->> 'code'), '')); account_name text := nullif(trim(input ->> 'name'), ''); target_type public.account_type := (input ->> 'accountType')::public.account_type; account_description text := nullif(trim(input ->> 'description'), ''); control_account boolean := coalesce((input ->> 'isControlAccount')::boolean, false); manual_posting boolean := coalesce((input ->> 'allowManualPosting')::boolean, true); active boolean := coalesce((input ->> 'isActive')::boolean, true); before_state jsonb; result_id uuid;
begin
  if not private.has_company_permission(org_id, target_company_id, 'organisation.accounting.configure') then raise exception 'Company accounting configuration permission is required' using errcode='42501'; end if;
  if account_code is null or account_code !~ '^[A-Z0-9.-]{2,30}$' or account_name is null or char_length(account_name)>150 or char_length(coalesce(account_description,''))>500 or (control_account and manual_posting) or not exists (select 1 from public.companies where id=target_company_id and organisation_id=org_id and is_active) or not exists (select 1 from public.account_groups where id=target_group_id and organisation_id=org_id and company_id=target_company_id and account_type=target_type and is_active) then raise exception 'Chart account input is invalid' using errcode='22023'; end if;
  if target_id is null then
    insert into public.chart_accounts (organisation_id, company_id, group_id, code, name, account_type, description, is_control_account, allow_manual_posting, is_active, created_by) values (org_id, target_company_id, target_group_id, account_code, account_name, target_type, account_description, control_account, manual_posting, active, auth.uid()) returning id into result_id;
  else
    select jsonb_build_object('groupId', group_id, 'code', code, 'name', name, 'accountType', account_type, 'isControlAccount', is_control_account, 'allowManualPosting', allow_manual_posting, 'isActive', is_active) into before_state from public.chart_accounts where id=target_id and organisation_id=org_id and company_id=target_company_id for update;
    if before_state is null then raise exception 'Chart account does not exist' using errcode='23503'; end if;
    update public.chart_accounts set group_id=target_group_id, code=account_code, name=account_name, account_type=target_type, description=account_description, is_control_account=control_account, allow_manual_posting=manual_posting, is_active=active where id=target_id returning id into result_id;
  end if;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, before_state, after_state) values (org_id, auth.uid(), case when target_id is null then 'chart_account_created' else 'chart_account_updated' end, 'chart_account', result_id, before_state, jsonb_build_object('companyId', target_company_id, 'groupId', target_group_id, 'code', account_code, 'name', account_name, 'accountType', target_type, 'isControlAccount', control_account, 'allowManualPosting', manual_posting, 'isActive', active));
  return result_id;
end; $$;

create or replace function public.create_fiscal_year(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; target_company_id uuid := (input ->> 'companyId')::uuid; year_name text := nullif(trim(input ->> 'name'), ''); year_start date := (input ->> 'startDate')::date; year_end date; year_id uuid; period_start date; period_end date; period_index integer;
begin
  if not private.has_company_permission(org_id, target_company_id, 'organisation.accounting.configure') then raise exception 'Company accounting configuration permission is required' using errcode='42501'; end if;
  if year_name is null or char_length(year_name) not between 2 and 100 or year_start is null or extract(day from year_start)<>1 or not exists (select 1 from public.companies where id=target_company_id and organisation_id=org_id and is_active) then raise exception 'Fiscal year input is invalid' using errcode='22023'; end if;
  year_end := (year_start + interval '1 year - 1 day')::date;
  perform pg_advisory_xact_lock(hashtext(target_company_id::text || 'fiscal-years'));
  if exists (select 1 from public.fiscal_years where company_id=target_company_id and daterange(start_date, end_date, '[]') && daterange(year_start, year_end, '[]')) then raise exception 'Fiscal years cannot overlap for a company' using errcode='23P01'; end if;
  insert into public.fiscal_years (organisation_id, company_id, name, start_date, end_date, created_by) values (org_id, target_company_id, year_name, year_start, year_end, auth.uid()) returning id into year_id;
  for period_index in 1..12 loop
    period_start := (year_start + make_interval(months => period_index - 1))::date;
    period_end := (year_start + make_interval(months => period_index) - interval '1 day')::date;
    insert into public.fiscal_periods (organisation_id, company_id, fiscal_year_id, period_number, name, start_date, end_date) values (org_id, target_company_id, year_id, period_index, 'Period ' || lpad(period_index::text, 2, '0'), period_start, period_end);
  end loop;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'fiscal_year_created', 'fiscal_year', year_id, jsonb_build_object('companyId', target_company_id, 'name', year_name, 'startDate', year_start, 'endDate', year_end, 'periodCount', 12, 'status', 'draft'));
  return year_id;
end; $$;

create or replace function public.create_custom_role(input jsonb) returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; role_code text := lower(nullif(trim(input ->> 'code'), '')); role_name text := nullif(trim(input ->> 'name'), ''); role_scope public.scope_type := (input ->> 'defaultScope')::public.scope_type; permission_codes text[] := array(select jsonb_array_elements_text(coalesce(input -> 'permissionCodes','[]'::jsonb))); role_id uuid;
begin
 if not private.has_organisation_permission(org_id,'organisation.roles.manage') then raise exception 'Organisation role management permission is required' using errcode='42501'; end if;
 if role_code is null or role_code !~ '^[a-z0-9_.-]{3,100}$' or role_name is null or role_scope not in ('organisation','company','branch','warehouse') or cardinality(permission_codes)=0 then raise exception 'Custom role input is invalid' using errcode='22023'; end if;
 if exists (select 1 from public.roles where organisation_id is null and code=role_code) then raise exception 'Custom role code conflicts with a system role' using errcode='23505'; end if;
 if exists (select 1 from unnest(permission_codes) code where code not in ('organisation.structure.manage','organisation.memberships.manage','organisation.audit.read','organisation.support_access.manage','organisation.localisation.manage','organisation.localisation.approve','organisation.parties.manage','organisation.catalog.manage','organisation.payment_references.manage','organisation.imports.manage','organisation.accounting.configure')) then raise exception 'Custom role contains unsupported permission' using errcode='22023'; end if;
 insert into public.roles (organisation_id,code,name,default_scope,is_system) values (org_id,role_code,role_name,role_scope,false) returning id into role_id;
 insert into public.role_permissions (role_id,permission_id) select role_id,id from public.permissions where code=any(permission_codes);
 insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (org_id,auth.uid(),'custom_role_created','role',role_id,input); return role_id;
end; $$;

revoke all on function public.create_account_group(jsonb), public.upsert_chart_account(jsonb), public.create_fiscal_year(jsonb) from public;
grant execute on function public.create_account_group(jsonb), public.upsert_chart_account(jsonb), public.create_fiscal_year(jsonb) to authenticated;
