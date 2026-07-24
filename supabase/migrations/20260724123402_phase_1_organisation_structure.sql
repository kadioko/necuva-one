insert into public.permissions (code, module_code, description)
values ('organisation.structure.manage', 'platform', 'Manage companies, branches, departments, and warehouses')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code = 'organisation.structure.manage'
where r.organisation_id is null and r.code = 'organisation.owner'
on conflict do nothing;

create or replace function private.has_organisation_permission(target_organisation_id uuid, permission_code text)
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.organisation_memberships m
    join public.membership_roles mr on mr.membership_id = m.id
    join public.roles r on r.id = mr.role_id
    join public.role_permissions rp on rp.role_id = r.id
    join public.permissions p on p.id = rp.permission_id
    join public.membership_scopes ms on ms.membership_id = m.id
    where m.organisation_id = target_organisation_id and m.user_id = auth.uid() and m.status = 'active'
      and p.code = permission_code and ms.scope = 'organisation'
  );
$$;

create or replace function public.add_organisation_structure(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  target_organisation_id uuid := (input ->> 'organisationId')::uuid;
  target_company_id uuid;
  target_branch_id uuid;
  result_id uuid;
  entity_type text := input ->> 'entityType';
  entity_name text := nullif(trim(input ->> 'name'), '');
  entity_code text := upper(nullif(trim(input ->> 'code'), ''));
begin
  if not private.has_organisation_permission(target_organisation_id, 'organisation.structure.manage') then
    raise exception 'Organisation structure management permission is required' using errcode = '42501';
  end if;
  if entity_type not in ('company', 'branch', 'department', 'warehouse') or entity_name is null then
    raise exception 'Structure input is invalid' using errcode = '22023';
  end if;
  if entity_type = 'company' then
    insert into public.companies (organisation_id, legal_name) values (target_organisation_id, entity_name) returning id into result_id;
  elsif entity_type = 'branch' then
    target_company_id := (input ->> 'companyId')::uuid;
    if entity_code is null or entity_code !~ '^[A-Z0-9_-]{2,30}$' then raise exception 'Branch code is invalid' using errcode = '22023'; end if;
    insert into public.branches (organisation_id, company_id, code, name) values (target_organisation_id, target_company_id, entity_code, entity_name) returning id into result_id;
  elsif entity_type = 'department' then
    target_company_id := (input ->> 'companyId')::uuid;
    target_branch_id := nullif(input ->> 'branchId', '')::uuid;
    insert into public.departments (organisation_id, company_id, branch_id, name) values (target_organisation_id, target_company_id, target_branch_id, entity_name) returning id into result_id;
  else
    target_company_id := (input ->> 'companyId')::uuid;
    target_branch_id := (input ->> 'branchId')::uuid;
    if entity_code is null or entity_code !~ '^[A-Z0-9_-]{2,30}$' then raise exception 'Warehouse code is invalid' using errcode = '22023'; end if;
    insert into public.warehouses (organisation_id, company_id, branch_id, code, name) values (target_organisation_id, target_company_id, target_branch_id, entity_code, entity_name) returning id into result_id;
  end if;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state)
  values (target_organisation_id, auth.uid(), 'organisation_structure_created', entity_type, result_id, input);
  return result_id;
end;
$$;

revoke all on function private.has_organisation_permission(uuid, text) from public;
revoke all on function public.add_organisation_structure(jsonb) from public;
grant execute on function public.add_organisation_structure(jsonb) to authenticated;
