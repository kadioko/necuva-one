insert into public.permissions (code, module_code, description) values ('organisation.roles.manage', 'platform', 'Create tenant-specific roles') on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_id) select r.id, p.id from public.roles r join public.permissions p on p.code = 'organisation.roles.manage' where r.organisation_id is null and r.code = 'organisation.owner' on conflict do nothing;

create or replace function public.create_custom_role(input jsonb) returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; role_code text := lower(nullif(trim(input ->> 'code'), '')); role_name text := nullif(trim(input ->> 'name'), ''); role_scope public.scope_type := (input ->> 'defaultScope')::public.scope_type; permission_codes text[] := array(select jsonb_array_elements_text(coalesce(input -> 'permissionCodes', '[]'::jsonb))); role_id uuid;
begin
 if not private.has_organisation_permission(org_id, 'organisation.roles.manage') then raise exception 'Organisation role management permission is required' using errcode = '42501'; end if;
 if role_code is null or role_code !~ '^[a-z0-9_.-]{3,100}$' or role_name is null or role_scope not in ('organisation','company','branch') or cardinality(permission_codes)=0 then raise exception 'Custom role input is invalid' using errcode = '22023'; end if;
 if exists (select 1 from unnest(permission_codes) code where code not in ('organisation.structure.manage','organisation.memberships.manage','organisation.audit.read','organisation.support_access.manage')) then raise exception 'Custom role contains unsupported permission' using errcode = '22023'; end if;
 insert into public.roles (organisation_id,code,name,default_scope,is_system) values (org_id,role_code,role_name,role_scope,false) returning id into role_id;
 insert into public.role_permissions (role_id,permission_id) select role_id,id from public.permissions where code = any(permission_codes);
 insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (org_id,auth.uid(),'custom_role_created','role',role_id,input);
 return role_id;
end; $$;
revoke all on function public.create_custom_role(jsonb) from public;
grant execute on function public.create_custom_role(jsonb) to authenticated;
