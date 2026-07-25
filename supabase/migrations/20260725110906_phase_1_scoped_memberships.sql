create or replace function private.has_organisation_permission(target_organisation_id uuid, permission_code text)
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.organisation_memberships m
    join public.membership_roles mr on mr.membership_id = m.id
    join public.roles r on r.id = mr.role_id
    join public.role_permissions rp on rp.role_id = r.id
    join public.permissions p on p.id = rp.permission_id
    join public.membership_scopes ms on ms.membership_id = m.id
    where m.organisation_id = target_organisation_id and m.user_id = auth.uid() and m.status = 'active' and p.code = permission_code
      and (ms.scope = 'organisation' or (ms.scope = 'company' and exists (select 1 from public.companies c where c.id = ms.scope_id and c.organisation_id = target_organisation_id)) or (ms.scope = 'branch' and exists (select 1 from public.branches b where b.id = ms.scope_id and b.organisation_id = target_organisation_id)))
  );
$$;

create or replace function public.manage_organisation_membership(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare target_organisation_id uuid := (input ->> 'organisationId')::uuid; target_user_id uuid := (input ->> 'userId')::uuid; target_role_code text := input ->> 'roleCode'; target_membership_id uuid; target_role_id uuid; target_status public.membership_status := coalesce((input ->> 'status')::public.membership_status, 'active'); target_scope public.scope_type := coalesce((input ->> 'scope')::public.scope_type, 'organisation'); target_scope_id uuid := nullif(input ->> 'scopeId', '')::uuid;
begin
 if not private.has_organisation_permission(target_organisation_id, 'organisation.memberships.manage') then raise exception 'Organisation membership management permission is required' using errcode = '42501'; end if;
 if target_role_code not in ('organisation.owner', 'company.admin', 'read.only') then raise exception 'Role assignment is invalid' using errcode = '22023'; end if;
 if target_role_code = 'company.admin' and target_scope <> 'company' then raise exception 'Company administrators require a company scope' using errcode = '22023'; end if;
 if target_scope = 'organisation' then target_scope_id := null; elsif target_scope not in ('company', 'branch') then raise exception 'Scope is invalid' using errcode = '22023'; end if;
 if target_scope = 'company' and not exists (select 1 from public.companies where id = target_scope_id and organisation_id = target_organisation_id) then raise exception 'Company scope is invalid' using errcode = '23503'; end if;
 if target_scope = 'branch' and not exists (select 1 from public.branches where id = target_scope_id and organisation_id = target_organisation_id) then raise exception 'Branch scope is invalid' using errcode = '23503'; end if;
 if not exists (select 1 from public.profiles where id = target_user_id) then raise exception 'User profile does not exist' using errcode = '23503'; end if;
 select id into target_role_id from public.roles where organisation_id is null and code = target_role_code;
 insert into public.organisation_memberships (organisation_id,user_id,status,joined_at) values (target_organisation_id,target_user_id,target_status,case when target_status='active' then now() else null end) on conflict (organisation_id,user_id) do update set status=excluded.status returning id into target_membership_id;
 delete from public.membership_roles where membership_id=target_membership_id; delete from public.membership_scopes where membership_id=target_membership_id;
 insert into public.membership_roles (membership_id,role_id) values (target_membership_id,target_role_id); insert into public.membership_scopes (membership_id,scope,scope_id) values (target_membership_id,target_scope,target_scope_id);
 insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (target_organisation_id,auth.uid(),'organisation_membership_managed','organisation_membership',target_membership_id,jsonb_build_object('userId',target_user_id,'roleCode',target_role_code,'scope',target_scope,'scopeId',target_scope_id,'status',target_status)); return target_membership_id;
end; $$;
