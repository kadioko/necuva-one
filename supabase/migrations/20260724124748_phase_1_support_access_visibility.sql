drop policy if exists support_access_participant_select on public.support_access_grants;
create policy support_access_authorised_select on public.support_access_grants
  for select using (
    requested_by = auth.uid() or support_user_id = auth.uid()
    or private.has_organisation_permission(organisation_id, 'organisation.support_access.manage')
  );
