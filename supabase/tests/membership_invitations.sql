begin;

select plan(5);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '40000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'inviter@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '40000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'invitee@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '40000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'outsider@example.test', 'not-used', now(), '{}', '{}', now(), now());

insert into public.organisations (id, legal_name, display_name)
values ('50000000-0000-0000-0000-000000000001', 'Invitation Tenant Limited', 'Invitation Tenant');

insert into public.organisation_memberships (organisation_id, user_id, status, joined_at)
values ('50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 'active', now());

insert into public.membership_roles (membership_id, role_id)
select m.id, r.id
from public.organisation_memberships m
join public.roles r on r.code = 'organisation.owner' and r.organisation_id is null
where m.organisation_id = '50000000-0000-0000-0000-000000000001' and m.user_id = '40000000-0000-0000-0000-000000000001';

insert into public.membership_scopes (membership_id, scope, scope_id)
select id, 'organisation', null
from public.organisation_memberships
where organisation_id = '50000000-0000-0000-0000-000000000001' and user_id = '40000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);

select is(
  public.create_membership_invitation(jsonb_build_object(
    'organisationId', '50000000-0000-0000-0000-000000000001',
    'email', 'invitee@example.test',
    'roleCode', 'read.only',
    'scope', 'organisation'
  )) is not null,
  true,
  'Membership manager can create an organisation-scoped invitation'
);

select lives_ok(
  $$select public.finalise_membership_invitation(id, '40000000-0000-0000-0000-000000000002') from public.organisation_invitations where email = 'invitee@example.test'$$,
  'Inviter can finalise a pending invitation'
);

select is(
  (select status from public.organisation_memberships where organisation_id = '50000000-0000-0000-0000-000000000001' and user_id = '40000000-0000-0000-0000-000000000002'),
  'invited'::public.membership_status,
  'Finalisation creates an invited membership'
);

select is(
  (select status from public.organisation_invitations where email = 'invitee@example.test'),
  'sent'::public.invitation_status,
  'Finalisation marks the invitation as sent'
);

select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.create_membership_invitation(jsonb_build_object('organisationId', '50000000-0000-0000-0000-000000000001', 'email', 'blocked@example.test', 'roleCode', 'read.only', 'scope', 'organisation'))$$,
  '42501',
  'Organisation membership management permission is required',
  'Unauthorised users cannot create invitations'
);

reset role;
select * from finish();

rollback;
