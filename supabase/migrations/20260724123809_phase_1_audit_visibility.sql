insert into public.permissions (code, module_code, description)
values ('organisation.audit.read', 'platform', 'View organisation audit events')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code = 'organisation.audit.read'
where r.organisation_id is null and r.code = 'organisation.owner'
on conflict do nothing;

drop policy if exists audit_events_member_select on public.audit_events;
create policy audit_events_permission_select on public.audit_events
  for select using (organisation_id is not null and private.has_organisation_permission(organisation_id, 'organisation.audit.read'));
