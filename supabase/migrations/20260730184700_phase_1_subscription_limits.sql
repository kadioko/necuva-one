create table public.subscription_plan_limits (
  plan_id uuid primary key references public.subscription_plans(id) on delete cascade,
  max_members integer check (max_members is null or max_members >= 0),
  max_companies integer check (max_companies is null or max_companies >= 0),
  max_branches integer check (max_branches is null or max_branches >= 0),
  max_warehouses integer check (max_warehouses is null or max_warehouses >= 0),
  updated_at timestamptz not null default now()
);
create trigger subscription_plan_limits_set_updated_at before update on public.subscription_plan_limits for each row execute function private.set_updated_at();
alter table public.subscription_plan_limits enable row level security;
alter table public.subscription_plan_limits force row level security;
grant select on public.subscription_plan_limits to authenticated;
create policy subscription_plan_limits_authenticated_select on public.subscription_plan_limits for select using (auth.uid() is not null);

create or replace function private.assert_plan_limit(target_plan_id uuid, target_organisation_id uuid, resource_code text, requested_count integer)
returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare configured_limit integer;
begin
  if resource_code not in ('members', 'companies', 'branches', 'warehouses') then raise exception 'Subscription resource is invalid' using errcode = '22023'; end if;
  select case resource_code when 'members' then max_members when 'companies' then max_companies when 'branches' then max_branches when 'warehouses' then max_warehouses end into configured_limit from public.subscription_plan_limits where plan_id = target_plan_id;
  if configured_limit is not null and requested_count > configured_limit then raise exception 'Subscription limit reached for %', resource_code using errcode = 'P0001'; end if;
end; $$;

create or replace function private.assert_subscription_limit(target_organisation_id uuid, resource_code text, requested_count integer)
returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare assigned_plan_id uuid;
begin
  select plan_id into assigned_plan_id from public.subscriptions where organisation_id = target_organisation_id;
  if assigned_plan_id is not null then perform private.assert_plan_limit(assigned_plan_id, target_organisation_id, resource_code, requested_count); end if;
end; $$;

create or replace function public.upsert_subscription_plan(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare plan_code text := lower(nullif(trim(input ->> 'code'), '')); plan_name text := nullif(trim(input ->> 'name'), ''); price_minor bigint := nullif(input ->> 'monthlyPriceMinor', '')::bigint; enabled boolean := coalesce((input ->> 'isActive')::boolean, true); max_member_count integer := nullif(input ->> 'maxMembers', '')::integer; max_company_count integer := nullif(input ->> 'maxCompanies', '')::integer; max_branch_count integer := nullif(input ->> 'maxBranches', '')::integer; max_warehouse_count integer := nullif(input ->> 'maxWarehouses', '')::integer; result_id uuid;
begin
  if not private.has_platform_permission('platform.plans.manage') then raise exception 'Platform plan management permission is required' using errcode = '42501'; end if;
  if plan_code is null or plan_code !~ '^[a-z0-9_.-]{3,100}$' or plan_name is null or price_minor < 0 or max_member_count < 0 or max_company_count < 0 or max_branch_count < 0 or max_warehouse_count < 0 then raise exception 'Subscription plan input is invalid' using errcode = '22023'; end if;
  insert into public.subscription_plans (code, name, monthly_price_minor, is_active) values (plan_code, plan_name, price_minor, enabled)
  on conflict (code) do update set name = excluded.name, monthly_price_minor = excluded.monthly_price_minor, is_active = excluded.is_active returning id into result_id;
  insert into public.subscription_plan_limits (plan_id, max_members, max_companies, max_branches, max_warehouses) values (result_id, max_member_count, max_company_count, max_branch_count, max_warehouse_count)
  on conflict (plan_id) do update set max_members = excluded.max_members, max_companies = excluded.max_companies, max_branches = excluded.max_branches, max_warehouses = excluded.max_warehouses;
  insert into public.audit_events (actor_user_id, action, entity_type, entity_id, after_state) values (auth.uid(), 'subscription_plan_upserted', 'subscription_plan', result_id, input);
  return result_id;
end; $$;

create or replace function public.assign_subscription_plan(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; plan_code text := lower(nullif(trim(input ->> 'planCode'), '')); plan_id uuid; subscription_id uuid;
begin
  if not private.has_platform_permission('platform.plans.manage') then raise exception 'Platform plan management permission is required' using errcode = '42501'; end if;
  select id into plan_id from public.subscription_plans where code = plan_code and is_active;
  if plan_id is null then raise exception 'Active subscription plan does not exist' using errcode = '23503'; end if;
  if not exists (select 1 from public.organisations where id = org_id) then raise exception 'Organisation does not exist' using errcode = '23503'; end if;
  perform private.assert_plan_limit(plan_id, org_id, 'members', (select count(*)::integer from public.organisation_memberships where organisation_id = org_id and status <> 'inactive'));
  perform private.assert_plan_limit(plan_id, org_id, 'companies', (select count(*)::integer from public.companies where organisation_id = org_id));
  perform private.assert_plan_limit(plan_id, org_id, 'branches', (select count(*)::integer from public.branches where organisation_id = org_id));
  perform private.assert_plan_limit(plan_id, org_id, 'warehouses', (select count(*)::integer from public.warehouses where organisation_id = org_id));
  insert into public.subscriptions (organisation_id, plan_id, starts_at) values (org_id, plan_id, now()) on conflict (organisation_id) do update set plan_id = excluded.plan_id, starts_at = excluded.starts_at, ends_at = null returning id into subscription_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'subscription_plan_assigned', 'subscription', subscription_id, jsonb_build_object('planCode', plan_code));
  return subscription_id;
end; $$;

create or replace function public.add_organisation_structure(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare target_organisation_id uuid := (input ->> 'organisationId')::uuid; target_company_id uuid; target_branch_id uuid; result_id uuid; entity_type text := input ->> 'entityType'; entity_name text := nullif(trim(input ->> 'name'), ''); entity_code text := upper(nullif(trim(input ->> 'code'), ''));
begin
  if not private.has_organisation_permission(target_organisation_id, 'organisation.structure.manage') then raise exception 'Organisation structure management permission is required' using errcode = '42501'; end if;
  if entity_type not in ('company', 'branch', 'department', 'warehouse') or entity_name is null then raise exception 'Structure input is invalid' using errcode = '22023'; end if;
  if entity_type = 'company' then perform private.assert_subscription_limit(target_organisation_id, 'companies', (select count(*)::integer + 1 from public.companies where organisation_id = target_organisation_id)); insert into public.companies (organisation_id, legal_name) values (target_organisation_id, entity_name) returning id into result_id;
  elsif entity_type = 'branch' then target_company_id := (input ->> 'companyId')::uuid; if entity_code is null or entity_code !~ '^[A-Z0-9_-]{2,30}$' then raise exception 'Branch code is invalid' using errcode = '22023'; end if; perform private.assert_subscription_limit(target_organisation_id, 'branches', (select count(*)::integer + 1 from public.branches where organisation_id = target_organisation_id)); insert into public.branches (organisation_id, company_id, code, name) values (target_organisation_id, target_company_id, entity_code, entity_name) returning id into result_id;
  elsif entity_type = 'department' then target_company_id := (input ->> 'companyId')::uuid; target_branch_id := nullif(input ->> 'branchId', '')::uuid; insert into public.departments (organisation_id, company_id, branch_id, name) values (target_organisation_id, target_company_id, target_branch_id, entity_name) returning id into result_id;
  else target_company_id := (input ->> 'companyId')::uuid; target_branch_id := (input ->> 'branchId')::uuid; if entity_code is null or entity_code !~ '^[A-Z0-9_-]{2,30}$' then raise exception 'Warehouse code is invalid' using errcode = '22023'; end if; perform private.assert_subscription_limit(target_organisation_id, 'warehouses', (select count(*)::integer + 1 from public.warehouses where organisation_id = target_organisation_id)); insert into public.warehouses (organisation_id, company_id, branch_id, code, name) values (target_organisation_id, target_company_id, target_branch_id, entity_code, entity_name) returning id into result_id;
  end if;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (target_organisation_id, auth.uid(), 'organisation_structure_created', entity_type, result_id, input);
  return result_id;
end; $$;

create or replace function public.manage_organisation_membership(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; user_id uuid := (input ->> 'userId')::uuid; role_code text := lower(nullif(trim(input ->> 'roleCode'), '')); target_membership_id uuid; role_id uuid; role_scope public.scope_type; member_status public.membership_status := coalesce((input ->> 'status')::public.membership_status,'active'); scope_type public.scope_type := coalesce((input ->> 'scope')::public.scope_type,'organisation'); target_scope_id uuid := nullif(input ->> 'scopeId','')::uuid; existing_status public.membership_status;
begin
 if not private.has_organisation_permission(org_id,'organisation.memberships.manage') then raise exception 'Organisation membership management permission is required' using errcode='42501'; end if;
 select id,default_scope into role_id,role_scope from public.roles where code=role_code and (organisation_id is null or organisation_id=org_id) order by (organisation_id=org_id) desc limit 1;
 if role_id is null or role_scope<>scope_type then raise exception 'Role assignment or scope is invalid' using errcode='22023'; end if;
 if scope_type='organisation' then target_scope_id:=null; elsif scope_type='company' and not exists(select 1 from public.companies where id=target_scope_id and organisation_id=org_id) then raise exception 'Company scope is invalid' using errcode='23503'; elsif scope_type='branch' and not exists(select 1 from public.branches where id=target_scope_id and organisation_id=org_id) then raise exception 'Branch scope is invalid' using errcode='23503'; elsif scope_type='warehouse' and not exists(select 1 from public.warehouses where id=target_scope_id and organisation_id=org_id) then raise exception 'Warehouse scope is invalid' using errcode='23503'; end if;
 if not exists(select 1 from public.profiles where id=user_id) then raise exception 'User profile does not exist' using errcode='23503'; end if;
 select status into existing_status from public.organisation_memberships where organisation_id=org_id and user_id=user_id;
 if member_status <> 'inactive' and (existing_status is null or existing_status = 'inactive') then perform private.assert_subscription_limit(org_id, 'members', (select count(*)::integer + 1 from public.organisation_memberships where organisation_id=org_id and status <> 'inactive')); end if;
 insert into public.organisation_memberships(organisation_id,user_id,status,joined_at) values(org_id,user_id,member_status,case when member_status='active' then now() else null end) on conflict(organisation_id,user_id) do update set status=excluded.status returning id into target_membership_id;
 delete from public.membership_roles where membership_id=target_membership_id; delete from public.membership_scopes where membership_id=target_membership_id;
 insert into public.membership_roles(membership_id,role_id) values(target_membership_id,role_id); insert into public.membership_scopes(membership_id,scope,scope_id) values(target_membership_id,scope_type,target_scope_id);
 insert into public.audit_events(organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values(org_id,auth.uid(),'organisation_membership_managed','organisation_membership',target_membership_id,input); return target_membership_id;
end; $$;

create or replace function public.finalise_membership_invitation(target_invitation_id uuid, target_invited_user_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare invite public.organisation_invitations%rowtype; membership_id uuid; existing_status public.membership_status;
begin
  select * into invite from public.organisation_invitations where id=target_invitation_id for update;
  if invite.id is null or invite.invited_by<>auth.uid() or invite.status<>'pending' or invite.expires_at<=now() then raise exception 'Invitation cannot be finalised' using errcode='42501'; end if;
  if not exists(select 1 from public.profiles where id=target_invited_user_id) then raise exception 'Invited user profile does not exist' using errcode='23503'; end if;
  select status into existing_status from public.organisation_memberships where organisation_id=invite.organisation_id and user_id=target_invited_user_id;
  if existing_status is null or existing_status = 'inactive' then perform private.assert_subscription_limit(invite.organisation_id, 'members', (select count(*)::integer + 1 from public.organisation_memberships where organisation_id=invite.organisation_id and status <> 'inactive')); end if;
  insert into public.organisation_memberships (organisation_id,user_id,status) values (invite.organisation_id,target_invited_user_id,'invited') on conflict (organisation_id,user_id) do update set status='invited' returning id into membership_id;
  delete from public.membership_roles where membership_id=membership_id; delete from public.membership_scopes where membership_id=membership_id;
  insert into public.membership_roles (membership_id,role_id) values (membership_id,invite.role_id); insert into public.membership_scopes (membership_id,scope,scope_id) values (membership_id,invite.scope,invite.scope_id);
  update public.organisation_invitations set invited_user_id=target_invited_user_id,status='sent',sent_at=now() where id=target_invitation_id;
  insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (invite.organisation_id,auth.uid(),'membership_invitation_sent','organisation_invitation',target_invitation_id,jsonb_build_object('invitedUserId',target_invited_user_id));
end; $$;

revoke all on function private.assert_plan_limit(uuid,uuid,text,integer), private.assert_subscription_limit(uuid,text,integer) from public;
