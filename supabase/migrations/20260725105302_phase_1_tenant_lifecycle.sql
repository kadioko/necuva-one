insert into public.permissions (code, module_code, description)
values ('platform.organisations.lifecycle.manage', 'platform', 'Activate, suspend, and close customer organisations')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code = 'platform.organisations.lifecycle.manage'
where r.organisation_id is null and r.code = 'platform.owner' on conflict do nothing;

create or replace function public.set_organisation_status(input jsonb)
returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare target_id uuid := (input ->> 'organisationId')::uuid; next_status public.organisation_status := (input ->> 'status')::public.organisation_status; change_reason text := nullif(trim(input ->> 'reason'), ''); previous_status public.organisation_status;
begin
  if not private.has_platform_permission('platform.organisations.lifecycle.manage') then raise exception 'Platform organisation lifecycle permission is required' using errcode = '42501'; end if;
  if next_status is null or change_reason is null or char_length(change_reason) < 10 then raise exception 'Status and a reason of at least 10 characters are required' using errcode = '22023'; end if;
  select status into previous_status from public.organisations where id = target_id for update;
  if previous_status is null then raise exception 'Organisation does not exist' using errcode = '23503'; end if;
  if previous_status = 'closed' and next_status <> 'closed' then raise exception 'A closed organisation cannot be reactivated' using errcode = '22023'; end if;
  update public.organisations set status = next_status where id = target_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, reason, before_state, after_state)
  values (target_id, auth.uid(), 'organisation_status_changed', 'organisation', target_id, change_reason, jsonb_build_object('status', previous_status), jsonb_build_object('status', next_status));
end; $$;
revoke all on function public.set_organisation_status(jsonb) from public;
grant execute on function public.set_organisation_status(jsonb) to authenticated;
