create or replace function public.manage_organisation_membership(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; user_id uuid := (input ->> 'userId')::uuid; role_code text := lower(nullif(trim(input ->> 'roleCode'), '')); target_membership_id uuid; role_id uuid; role_scope public.scope_type; member_status public.membership_status := coalesce((input ->> 'status')::public.membership_status, 'active'); scope_type public.scope_type := coalesce((input ->> 'scope')::public.scope_type, 'organisation'); scope_id uuid := nullif(input ->> 'scopeId', '')::uuid;
begin
 if not private.has_organisation_permission(org_id, 'organisation.memberships.manage') then raise exception 'Organisation membership management permission is required' using errcode = '42501'; end if;
 select id, default_scope into role_id, role_scope from public.roles where code = role_code and (organisation_id is null or organisation_id = org_id);
 if role_id is null then raise exception 'Role assignment is invalid' using errcode = '22023'; end if;
 if role_scope <> scope_type then raise exception 'Role scope must match the assigned scope' using errcode = '22023'; end if;
 if scope_type = 'organisation' then scope_id := null; elsif scope_type = 'company' and not exists (select 1 from public.companies where id=scope_id and organisation_id=org_id) then raise exception 'Company scope is invalid' using errcode = '23503'; elsif scope_type = 'branch' and not exists (select 1 from public.branches where id=scope_id and organisation_id=org_id) then raise exception 'Branch scope is invalid' using errcode = '23503'; end if;
 if not exists (select 1 from public.profiles where id=user_id) then raise exception 'User profile does not exist' using errcode = '23503'; end if;
 insert into public.organisation_memberships (organisation_id,user_id,status,joined_at) values (org_id,user_id,member_status,case when member_status='active' then now() else null end) on conflict (organisation_id,user_id) do update set status=excluded.status returning id into target_membership_id;
 delete from public.membership_roles where membership_id=target_membership_id; delete from public.membership_scopes where membership_id=target_membership_id;
 insert into public.membership_roles (membership_id,role_id) values (target_membership_id,role_id); insert into public.membership_scopes (membership_id,scope,scope_id) values (target_membership_id,scope_type,scope_id);
 insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (org_id,auth.uid(),'organisation_membership_managed','organisation_membership',target_membership_id,input); return target_membership_id;
end; $$;
