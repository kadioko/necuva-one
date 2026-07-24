insert into public.permissions (code, module_code, description)
values ('organisation.memberships.manage', 'platform', 'Manage organisation memberships and role assignments')
on conflict (code) do nothing;

insert into public.roles (organisation_id, code, name, default_scope, is_system) values
  (null, 'read.only', 'Read-Only User', 'organisation', true),
  (null, 'company.admin', 'Company Administrator', 'company', true)
on conflict (organisation_id, code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code = 'organisation.memberships.manage'
where r.organisation_id is null and r.code = 'organisation.owner'
on conflict do nothing;

create or replace function public.manage_organisation_membership(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  target_organisation_id uuid := (input ->> 'organisationId')::uuid;
  target_user_id uuid := (input ->> 'userId')::uuid;
  target_role_code text := input ->> 'roleCode';
  target_membership_id uuid;
  target_role_id uuid;
  target_status public.membership_status := coalesce((input ->> 'status')::public.membership_status, 'active');
begin
  if not private.has_organisation_permission(target_organisation_id, 'organisation.memberships.manage') then
    raise exception 'Organisation membership management permission is required' using errcode = '42501';
  end if;
  if target_role_code not in ('organisation.owner', 'company.admin', 'read.only') then
    raise exception 'Role assignment is invalid' using errcode = '22023';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id) then
    raise exception 'User profile does not exist' using errcode = '23503';
  end if;
  select id into target_role_id from public.roles where organisation_id is null and code = target_role_code;
  insert into public.organisation_memberships (organisation_id, user_id, status, joined_at)
  values (target_organisation_id, target_user_id, target_status, case when target_status = 'active' then now() else null end)
  on conflict (organisation_id, user_id) do update set status = excluded.status, joined_at = coalesce(public.organisation_memberships.joined_at, excluded.joined_at)
  returning id into target_membership_id;
  delete from public.membership_roles where membership_id = target_membership_id;
  insert into public.membership_roles (membership_id, role_id) values (target_membership_id, target_role_id);
  insert into public.membership_scopes (membership_id, scope) values (target_membership_id, 'organisation') on conflict do nothing;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state)
  values (target_organisation_id, auth.uid(), 'organisation_membership_managed', 'organisation_membership', target_membership_id,
    jsonb_build_object('userId', target_user_id, 'roleCode', target_role_code, 'status', target_status));
  return target_membership_id;
end;
$$;

revoke all on function public.manage_organisation_membership(jsonb) from public;
grant execute on function public.manage_organisation_membership(jsonb) to authenticated;
