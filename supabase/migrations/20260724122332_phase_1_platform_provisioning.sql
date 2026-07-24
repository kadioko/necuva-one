create table public.platform_role_assignments (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  assigned_by uuid references public.profiles(id) on delete set null,
  primary key (profile_id, role_id)
);

insert into public.permissions (code, module_code, description) values
  ('platform.organisations.provision', 'platform', 'Provision customer organisations'),
  ('platform.bootstrap.manage', 'platform', 'Bootstrap the initial platform owner')
on conflict (code) do nothing;

insert into public.roles (organisation_id, code, name, default_scope, is_system) values
  (null, 'platform.owner', 'Necuva Platform Owner', 'platform', true),
  (null, 'organisation.owner', 'Customer Organisation Owner', 'organisation', true)
on conflict (organisation_id, code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in ('platform.organisations.provision', 'platform.bootstrap.manage')
where r.organisation_id is null and r.code = 'platform.owner'
on conflict do nothing;

create or replace function private.has_platform_permission(permission_code text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.profiles profile
    join public.platform_role_assignments assignment on assignment.profile_id = profile.id
    join public.roles role on role.id = assignment.role_id
    join public.role_permissions role_permission on role_permission.role_id = role.id
    join public.permissions permission on permission.id = role_permission.permission_id
    where profile.id = auth.uid()
      and profile.is_platform_staff
      and role.organisation_id is null
      and role.default_scope = 'platform'
      and permission.code = permission_code
  );
$$;

create or replace function public.bootstrap_platform_owner(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  platform_owner_role_id uuid;
begin
  if exists (
    select 1
    from public.platform_role_assignments assignment
    join public.roles role on role.id = assignment.role_id
    where role.organisation_id is null and role.code = 'platform.owner'
  ) then
    raise exception 'A platform owner has already been bootstrapped' using errcode = '42501';
  end if;

  select id into platform_owner_role_id
  from public.roles
  where organisation_id is null and code = 'platform.owner';

  if platform_owner_role_id is null then
    raise exception 'Platform owner role is not configured' using errcode = '55000';
  end if;

  if not exists (select 1 from public.profiles where id = target_user_id) then
    raise exception 'Bootstrap user profile does not exist' using errcode = '23503';
  end if;

  update public.profiles set is_platform_staff = true where id = target_user_id;
  insert into public.platform_role_assignments (profile_id, role_id, assigned_by)
  values (target_user_id, platform_owner_role_id, target_user_id);
  insert into public.audit_events (actor_user_id, action, entity_type, entity_id, after_state)
  values (
    target_user_id,
    'platform_owner_bootstrapped',
    'profile',
    target_user_id,
    jsonb_build_object('role', 'platform.owner')
  );
end;
$$;

create or replace function public.provision_organisation(input jsonb)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  new_organisation_id uuid;
  new_company_id uuid;
  new_branch_id uuid;
  owner_membership_id uuid;
  organisation_owner_role_id uuid;
  owner_user_id uuid;
  organisation_legal_name text;
  organisation_display_name text;
  company_legal_name text;
  branch_code text;
  branch_name text;
begin
  if not private.has_platform_permission('platform.organisations.provision') then
    raise exception 'Platform organisation provisioning permission is required' using errcode = '42501';
  end if;

  organisation_legal_name := nullif(trim(input ->> 'organisationLegalName'), '');
  organisation_display_name := nullif(trim(input ->> 'organisationDisplayName'), '');
  company_legal_name := nullif(trim(input ->> 'companyLegalName'), '');
  branch_code := upper(nullif(trim(input ->> 'branchCode'), ''));
  branch_name := nullif(trim(input ->> 'branchName'), '');

  begin
    owner_user_id := (input ->> 'ownerUserId')::uuid;
  exception when invalid_text_representation then
    raise exception 'ownerUserId must be a UUID' using errcode = '22023';
  end;

  if organisation_legal_name is null or char_length(organisation_legal_name) > 250
    or organisation_display_name is null or char_length(organisation_display_name) > 250
    or company_legal_name is null or char_length(company_legal_name) > 250
    or branch_name is null or char_length(branch_name) > 150
    or branch_code is null or branch_code !~ '^[A-Z0-9_-]{2,30}$' then
    raise exception 'Provisioning input is invalid' using errcode = '22023';
  end if;

  if not exists (select 1 from public.profiles where id = owner_user_id) then
    raise exception 'Organisation owner profile does not exist' using errcode = '23503';
  end if;

  select id into organisation_owner_role_id
  from public.roles
  where organisation_id is null and code = 'organisation.owner';

  if organisation_owner_role_id is null then
    raise exception 'Organisation owner role is not configured' using errcode = '55000';
  end if;

  insert into public.organisations (legal_name, display_name)
  values (organisation_legal_name, organisation_display_name)
  returning id into new_organisation_id;

  insert into public.companies (organisation_id, legal_name)
  values (new_organisation_id, company_legal_name)
  returning id into new_company_id;

  insert into public.branches (organisation_id, company_id, code, name)
  values (new_organisation_id, new_company_id, branch_code, branch_name)
  returning id into new_branch_id;

  insert into public.organisation_memberships (organisation_id, user_id, status, joined_at)
  values (new_organisation_id, owner_user_id, 'active', now())
  returning id into owner_membership_id;

  insert into public.membership_roles (membership_id, role_id)
  values (owner_membership_id, organisation_owner_role_id);

  insert into public.membership_scopes (membership_id, scope)
  values (owner_membership_id, 'organisation');

  insert into public.implementation_projects (organisation_id, stage)
  values (new_organisation_id, 'tenant_provisioned');

  insert into public.audit_events (
    organisation_id, actor_user_id, action, entity_type, entity_id, after_state
  ) values (
    new_organisation_id,
    auth.uid(),
    'organisation_provisioned',
    'organisation',
    new_organisation_id,
    jsonb_build_object(
      'companyId', new_company_id,
      'branchId', new_branch_id,
      'ownerUserId', owner_user_id
    )
  );

  return new_organisation_id;
end;
$$;

revoke all on table public.platform_role_assignments from anon, authenticated;
grant select on public.platform_role_assignments to authenticated;

alter table public.platform_role_assignments enable row level security;
alter table public.platform_role_assignments force row level security;
create policy platform_role_assignments_self_select on public.platform_role_assignments
  for select using (profile_id = auth.uid());

revoke all on function private.has_platform_permission(text) from public;
revoke all on function public.bootstrap_platform_owner(uuid) from public;
revoke all on function public.provision_organisation(jsonb) from public;
grant execute on function public.bootstrap_platform_owner(uuid) to service_role;
grant execute on function public.provision_organisation(jsonb) to authenticated;
