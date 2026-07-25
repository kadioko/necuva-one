insert into public.permissions (code, module_code, description) values ('platform.implementations.manage', 'platform', 'Manage client implementation stages') on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_id) select r.id, p.id from public.roles r join public.permissions p on p.code = 'platform.implementations.manage' where r.organisation_id is null and r.code = 'platform.owner' on conflict do nothing;
create or replace function public.set_implementation_stage(input jsonb) returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; next_stage public.implementation_stage := (input ->> 'stage')::public.implementation_stage; previous_stage public.implementation_stage;
begin
 if not private.has_platform_permission('platform.implementations.manage') then raise exception 'Platform implementation management permission is required' using errcode = '42501'; end if;
 select stage into previous_stage from public.implementation_projects where organisation_id = org_id for update;
 if previous_stage is null then raise exception 'Implementation project does not exist' using errcode = '23503'; end if;
 update public.implementation_projects set stage = next_stage where organisation_id = org_id;
 insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, before_state, after_state) values (org_id, auth.uid(), 'implementation_stage_changed', 'implementation_project', (select id from public.implementation_projects where organisation_id = org_id), jsonb_build_object('stage', previous_stage), jsonb_build_object('stage', next_stage));
end; $$;
revoke all on function public.set_implementation_stage(jsonb) from public;
grant execute on function public.set_implementation_stage(jsonb) to authenticated;
