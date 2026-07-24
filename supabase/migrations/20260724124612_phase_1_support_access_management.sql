insert into public.permissions (code, module_code, description)
values ('organisation.support_access.manage', 'platform', 'Grant and revoke temporary support access')
on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code = 'organisation.support_access.manage'
where r.organisation_id is null and r.code = 'organisation.owner' on conflict do nothing;

create or replace function public.grant_support_access(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; support_id uuid := (input ->> 'supportUserId')::uuid; grant_id uuid; expires timestamptz := (input ->> 'expiresAt')::timestamptz; access_reason text := nullif(trim(input ->> 'reason'), '');
begin
  if not private.has_organisation_permission(org_id, 'organisation.support_access.manage') then raise exception 'Support access management permission is required' using errcode = '42501'; end if;
  if access_reason is null or char_length(access_reason) < 10 or expires <= now() or expires > now() + interval '7 days' then raise exception 'Support access input is invalid' using errcode = '22023'; end if;
  if not exists (select 1 from public.profiles where id = support_id and is_platform_staff) then raise exception 'Support user must be active platform staff' using errcode = '23503'; end if;
  insert into public.support_access_grants (organisation_id, requested_by, granted_by, support_user_id, reason, starts_at, expires_at, status)
  values (org_id, auth.uid(), auth.uid(), support_id, access_reason, now(), expires, 'active') returning id into grant_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, reason, after_state)
  values (org_id, auth.uid(), 'support_access_granted', 'support_access_grant', grant_id, access_reason, jsonb_build_object('supportUserId', support_id, 'expiresAt', expires));
  return grant_id;
end; $$;

create or replace function public.revoke_support_access(grant_id uuid, revoke_reason text)
returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid;
begin
  select organisation_id into org_id from public.support_access_grants where id = grant_id;
  if org_id is null or not private.has_organisation_permission(org_id, 'organisation.support_access.manage') then raise exception 'Support access management permission is required' using errcode = '42501'; end if;
  update public.support_access_grants set status = 'revoked', revoked_at = now() where id = grant_id and status = 'active';
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, reason) values (org_id, auth.uid(), 'support_access_revoked', 'support_access_grant', grant_id, nullif(trim(revoke_reason), ''));
end; $$;
revoke all on function public.grant_support_access(jsonb) from public;
revoke all on function public.revoke_support_access(uuid, text) from public;
grant execute on function public.grant_support_access(jsonb), public.revoke_support_access(uuid, text) to authenticated;
