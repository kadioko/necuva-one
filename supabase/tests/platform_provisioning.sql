begin;

select plan(3);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '30000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'platform-owner@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '30000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'organisation-owner@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '30000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'unauthorised@example.test', 'not-used', now(), '{}', '{}', now(), now());

update public.profiles set is_platform_staff = true where id = '30000000-0000-0000-0000-000000000001';
insert into public.platform_role_assignments (profile_id, role_id)
select '30000000-0000-0000-0000-000000000001', id from public.roles where code = 'platform.owner' and organisation_id is null;

set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000001', true);

select is(
  public.provision_organisation(jsonb_build_object(
    'organisationLegalName', 'Provisioned Limited',
    'organisationDisplayName', 'Provisioned',
    'companyLegalName', 'Provisioned Limited',
    'branchCode', 'HQ',
    'branchName', 'Head Office',
    'ownerUserId', '30000000-0000-0000-0000-000000000002'
  )) is not null,
  true,
  'Platform owner can provision an organisation'
);

reset role;
select is(
  (select count(*) from public.organisation_memberships where user_id = '30000000-0000-0000-0000-000000000002' and status = 'active'),
  1::bigint,
  'Provisioning assigns an active organisation owner membership'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.provision_organisation(jsonb_build_object('organisationLegalName', 'Denied Ltd', 'organisationDisplayName', 'Denied', 'companyLegalName', 'Denied Ltd', 'branchCode', 'HQ', 'branchName', 'Head Office', 'ownerUserId', '30000000-0000-0000-0000-000000000002'))$$,
  '42501',
  'Platform organisation provisioning permission is required',
  'Unauthorised users cannot provision organisations'
);

reset role;
select * from finish();

rollback;
