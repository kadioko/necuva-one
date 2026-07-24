begin;

select plan(3);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'tenant-a@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'tenant-b@example.test', 'not-used', now(), '{}', '{}', now(), now());

insert into public.organisations (id, legal_name, display_name) values
  ('20000000-0000-0000-0000-000000000001', 'Tenant A Limited', 'Tenant A'),
  ('20000000-0000-0000-0000-000000000002', 'Tenant B Limited', 'Tenant B');

insert into public.organisation_memberships (organisation_id, user_id, status, joined_at) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'active', now()),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'active', now());

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select results_eq(
  'select id from public.organisations order by id',
  array['20000000-0000-0000-0000-000000000001'::uuid],
  'Tenant A cannot read Tenant B'
);

select results_eq(
  $$update public.organisations set display_name = 'Attempted change' where id = '20000000-0000-0000-0000-000000000002' returning id$$,
  array[]::uuid[],
  'Tenant A cannot modify Tenant B'
);

select is(
  (select count(*) from public.support_access_grants),
  0::bigint,
  'Support staff have no implicit tenant access grant'
);

reset role;
select * from finish();

rollback;
