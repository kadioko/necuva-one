begin;

select plan(4);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '80000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'party-owner@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '80000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'party-outsider@example.test', 'not-used', now(), '{}', '{}', now(), now());
insert into public.organisations (id, legal_name, display_name)
values ('90000000-0000-0000-0000-000000000001', 'Party Tenant Limited', 'Party Tenant');
insert into public.organisation_memberships (organisation_id, user_id, status, joined_at)
values ('90000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001', 'active', now());
insert into public.membership_roles (membership_id, role_id)
select m.id, r.id from public.organisation_memberships m join public.roles r on r.code = 'organisation.owner' and r.organisation_id is null
where m.organisation_id = '90000000-0000-0000-0000-000000000001';
insert into public.membership_scopes (membership_id, scope, scope_id)
select id, 'organisation', null from public.organisation_memberships where organisation_id = '90000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', true);
select is(
  public.create_business_party_category(jsonb_build_object('organisationId', '90000000-0000-0000-0000-000000000001', 'partyType', 'customer', 'name', 'Retail')) is not null,
  true,
  'Organisation owner can create a party category'
);
select is(
  public.upsert_business_party(jsonb_build_object('organisationId', '90000000-0000-0000-0000-000000000001', 'partyType', 'customer', 'externalCode', 'ACME', 'displayName', 'Acme Limited', 'isActive', 'true')) is not null,
  true,
  'Organisation owner can create a customer party'
);
select lives_ok(
  $$select public.add_business_party_contact(jsonb_build_object('organisationId', '90000000-0000-0000-0000-000000000001', 'partyId', id, 'fullName', 'Asha Mushi', 'email', 'asha@acme.test', 'isPrimary', 'true')) from public.business_parties where external_code = 'ACME'$$,
  'Organisation owner can attach a contact to a party'
);

select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$select public.upsert_business_party(jsonb_build_object('organisationId', '90000000-0000-0000-0000-000000000001', 'partyType', 'supplier', 'externalCode', 'DENIED', 'displayName', 'Denied Supplier', 'isActive', 'true'))$$,
  '42501',
  'Organisation party management permission is required',
  'Unauthorised users cannot create tenant parties'
);

reset role;
select * from finish();

rollback;
