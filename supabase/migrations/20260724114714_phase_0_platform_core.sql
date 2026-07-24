-- Phase 0: secure platform hierarchy. Financial and operational modules are out of scope.
create extension if not exists pgcrypto;

create schema if not exists private;
revoke all on schema private from public;

create type public.organisation_status as enum ('trial', 'active', 'grace_period', 'suspended', 'closed');
create type public.membership_status as enum ('invited', 'active', 'inactive');
create type public.scope_type as enum ('platform', 'organisation', 'company', 'branch', 'department', 'warehouse', 'own');
create type public.support_access_status as enum ('requested', 'active', 'revoked', 'expired');
create type public.implementation_stage as enum (
  'lead', 'qualified', 'discovery', 'proposal', 'contract_signed', 'tenant_provisioned',
  'data_collection', 'configuration', 'initial_migration', 'user_testing', 'training',
  'final_migration', 'go_live', 'hypercare', 'active_support'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 200),
  locale text not null default 'en-TZ' check (locale in ('en-TZ', 'sw-TZ')),
  timezone text not null default 'Africa/Dar_es_Salaam',
  is_platform_staff boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organisations (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null check (char_length(trim(legal_name)) between 1 and 250),
  display_name text not null check (char_length(trim(display_name)) between 1 and 250),
  status public.organisation_status not null default 'trial',
  default_currency_code char(3) not null default 'TZS',
  default_locale text not null default 'en-TZ' check (default_locale in ('en-TZ', 'sw-TZ')),
  timezone text not null default 'Africa/Dar_es_Salaam',
  financial_year_start_month smallint not null default 1 check (financial_year_start_month between 1 and 12),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, status)
);

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete restrict,
  legal_name text not null check (char_length(trim(legal_name)) between 1 and 250),
  registration_number text,
  tin text,
  vrn text,
  currency_code char(3) not null default 'TZS',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organisation_id)
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  company_id uuid not null,
  code text not null check (code ~ '^[A-Z0-9_-]{2,30}$'),
  name text not null check (char_length(trim(name)) between 1 and 150),
  timezone text not null default 'Africa/Dar_es_Salaam',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (company_id, organisation_id) references public.companies(id, organisation_id) on delete restrict,
  unique (organisation_id, code),
  unique (id, organisation_id)
);

create table public.departments (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  company_id uuid not null,
  branch_id uuid,
  name text not null check (char_length(trim(name)) between 1 and 150),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (company_id, organisation_id) references public.companies(id, organisation_id) on delete restrict,
  foreign key (branch_id, organisation_id) references public.branches(id, organisation_id) on delete restrict,
  unique (id, organisation_id)
);

create table public.warehouses (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  company_id uuid not null,
  branch_id uuid not null,
  code text not null check (code ~ '^[A-Z0-9_-]{2,30}$'),
  name text not null check (char_length(trim(name)) between 1 and 150),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (company_id, organisation_id) references public.companies(id, organisation_id) on delete restrict,
  foreign key (branch_id, organisation_id) references public.branches(id, organisation_id) on delete restrict,
  unique (organisation_id, code),
  unique (id, organisation_id)
);

create table public.organisation_memberships (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status public.membership_status not null default 'invited',
  joined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organisation_id, user_id),
  unique (id, organisation_id)
);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid references public.organisations(id) on delete cascade,
  code text not null check (code ~ '^[a-z0-9_.-]{3,100}$'),
  name text not null check (char_length(trim(name)) between 1 and 150),
  default_scope public.scope_type not null,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (organisation_id, code)
);

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9_.-]{3,150}$'),
  module_code text not null,
  description text not null,
  created_at timestamptz not null default now()
);

create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

create table public.membership_roles (
  membership_id uuid not null references public.organisation_memberships(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  primary key (membership_id, role_id)
);

create table public.membership_scopes (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.organisation_memberships(id) on delete cascade,
  scope public.scope_type not null,
  scope_id uuid,
  created_at timestamptz not null default now(),
  check ((scope in ('platform', 'organisation', 'own') and scope_id is null) or (scope not in ('platform', 'organisation', 'own') and scope_id is not null)),
  unique nulls not distinct (membership_id, scope, scope_id)
);

create table public.support_access_grants (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  requested_by uuid not null references public.profiles(id),
  granted_by uuid references public.profiles(id),
  support_user_id uuid not null references public.profiles(id),
  reason text not null check (char_length(trim(reason)) between 10 and 1000),
  starts_at timestamptz not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  status public.support_access_status not null default 'requested',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_at > starts_at)
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid references public.organisations(id) on delete restrict,
  actor_user_id uuid references public.profiles(id) on delete set null,
  action text not null check (char_length(trim(action)) between 3 and 150),
  entity_type text not null check (char_length(trim(entity_type)) between 3 and 150),
  entity_id uuid,
  reason text,
  before_state jsonb,
  after_state jsonb,
  request_ip inet,
  occurred_at timestamptz not null default now()
);

create table public.modules (
  code text primary key check (code ~ '^[a-z0-9_.-]{3,100}$'),
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9_.-]{3,100}$'),
  name text not null,
  monthly_price_minor bigint,
  currency_code char(3) not null default 'TZS',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check (monthly_price_minor is null or monthly_price_minor >= 0)
);

create table public.plan_modules (
  plan_id uuid not null references public.subscription_plans(id) on delete cascade,
  module_code text not null references public.modules(code) on delete restrict,
  primary key (plan_id, module_code)
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null unique references public.organisations(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id) on delete restrict,
  starts_at timestamptz not null,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create table public.implementation_projects (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null unique references public.organisations(id) on delete cascade,
  stage public.implementation_stage not null default 'lead',
  industry text,
  target_go_live_date date,
  risks text,
  outstanding_actions text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index organisations_status_idx on public.organisations (status);
create index companies_organisation_idx on public.companies (organisation_id);
create index branches_organisation_company_idx on public.branches (organisation_id, company_id);
create index memberships_user_idx on public.organisation_memberships (user_id, organisation_id) where status = 'active';
create index audit_events_organisation_occurred_idx on public.audit_events (organisation_id, occurred_at desc);
create index support_access_active_idx on public.support_access_grants (organisation_id, support_user_id, starts_at, expires_at) where status = 'active';

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$ begin new.updated_at = now(); return new; end; $$;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), split_part(new.email, '@', 1)));
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles for each row execute function private.set_updated_at();
create trigger organisations_set_updated_at before update on public.organisations for each row execute function private.set_updated_at();
create trigger companies_set_updated_at before update on public.companies for each row execute function private.set_updated_at();
create trigger branches_set_updated_at before update on public.branches for each row execute function private.set_updated_at();
create trigger departments_set_updated_at before update on public.departments for each row execute function private.set_updated_at();
create trigger warehouses_set_updated_at before update on public.warehouses for each row execute function private.set_updated_at();
create trigger memberships_set_updated_at before update on public.organisation_memberships for each row execute function private.set_updated_at();
create trigger roles_set_updated_at before update on public.roles for each row execute function private.set_updated_at();
create trigger support_grants_set_updated_at before update on public.support_access_grants for each row execute function private.set_updated_at();
create trigger implementation_projects_set_updated_at before update on public.implementation_projects for each row execute function private.set_updated_at();
create trigger on_auth_user_created after insert on auth.users for each row execute function private.handle_new_user();

create or replace function private.is_active_organisation_member(target_organisation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.organisation_memberships m
    join public.organisations o on o.id = m.organisation_id
    where m.organisation_id = target_organisation_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and o.status in ('trial', 'active', 'grace_period')
  );
$$;

create or replace function private.has_active_support_access(target_organisation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.support_access_grants g
    where g.organisation_id = target_organisation_id
      and g.support_user_id = auth.uid()
      and g.status = 'active'
      and g.revoked_at is null
      and g.starts_at <= now()
      and g.expires_at > now()
  );
$$;

revoke all on all tables in schema public from anon, authenticated;
grant usage on schema public to authenticated;
grant select on public.profiles to authenticated;
grant select on public.organisations, public.companies, public.branches, public.departments, public.warehouses, public.organisation_memberships, public.roles, public.permissions, public.role_permissions, public.membership_roles, public.membership_scopes, public.audit_events, public.modules, public.subscription_plans, public.plan_modules, public.subscriptions, public.implementation_projects, public.support_access_grants to authenticated;

alter table public.profiles enable row level security;
alter table public.organisations enable row level security;
alter table public.companies enable row level security;
alter table public.branches enable row level security;
alter table public.departments enable row level security;
alter table public.warehouses enable row level security;
alter table public.organisation_memberships enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.membership_roles enable row level security;
alter table public.membership_scopes enable row level security;
alter table public.support_access_grants enable row level security;
alter table public.audit_events enable row level security;
alter table public.modules enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.plan_modules enable row level security;
alter table public.subscriptions enable row level security;
alter table public.implementation_projects enable row level security;

alter table public.profiles force row level security;
alter table public.organisations force row level security;
alter table public.companies force row level security;
alter table public.branches force row level security;
alter table public.departments force row level security;
alter table public.warehouses force row level security;
alter table public.organisation_memberships force row level security;
alter table public.roles force row level security;
alter table public.permissions force row level security;
alter table public.role_permissions force row level security;
alter table public.membership_roles force row level security;
alter table public.membership_scopes force row level security;
alter table public.support_access_grants force row level security;
alter table public.audit_events force row level security;
alter table public.modules force row level security;
alter table public.subscription_plans force row level security;
alter table public.plan_modules force row level security;
alter table public.subscriptions force row level security;
alter table public.implementation_projects force row level security;

create policy profiles_self on public.profiles for select using (id = auth.uid());
create policy organisations_member_select on public.organisations for select using (private.is_active_organisation_member(id));
create policy companies_member_select on public.companies for select using (private.is_active_organisation_member(organisation_id));
create policy branches_member_select on public.branches for select using (private.is_active_organisation_member(organisation_id));
create policy departments_member_select on public.departments for select using (private.is_active_organisation_member(organisation_id));
create policy warehouses_member_select on public.warehouses for select using (private.is_active_organisation_member(organisation_id));
create policy memberships_self_select on public.organisation_memberships for select using (user_id = auth.uid());
create policy roles_member_select on public.roles for select using (organisation_id is null or private.is_active_organisation_member(organisation_id));
create policy permissions_authenticated_select on public.permissions for select using (auth.uid() is not null);
create policy role_permissions_member_select on public.role_permissions for select using (exists (select 1 from public.roles r where r.id = role_id and (r.organisation_id is null or private.is_active_organisation_member(r.organisation_id))));
create policy membership_roles_self_select on public.membership_roles for select using (exists (select 1 from public.organisation_memberships m where m.id = membership_id and m.user_id = auth.uid()));
create policy membership_scopes_self_select on public.membership_scopes for select using (exists (select 1 from public.organisation_memberships m where m.id = membership_id and m.user_id = auth.uid()));
create policy support_access_participant_select on public.support_access_grants for select using (requested_by = auth.uid() or support_user_id = auth.uid() or private.is_active_organisation_member(organisation_id));
create policy audit_events_member_select on public.audit_events for select using (organisation_id is not null and private.is_active_organisation_member(organisation_id));
create policy modules_authenticated_select on public.modules for select using (auth.uid() is not null);
create policy subscription_plans_authenticated_select on public.subscription_plans for select using (auth.uid() is not null);
create policy plan_modules_authenticated_select on public.plan_modules for select using (auth.uid() is not null);
create policy subscriptions_member_select on public.subscriptions for select using (private.is_active_organisation_member(organisation_id));
create policy implementation_projects_member_select on public.implementation_projects for select using (private.is_active_organisation_member(organisation_id));
