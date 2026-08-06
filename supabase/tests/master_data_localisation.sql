begin;

select plan(5);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '60000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'localisation-owner@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '60000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'localisation-outsider@example.test', 'not-used', now(), '{}', '{}', now(), now());

insert into public.organisations (id, legal_name, display_name)
values ('70000000-0000-0000-0000-000000000001', 'Localisation Tenant Limited', 'Localisation Tenant');
insert into public.currencies (code, name, symbol, decimal_places)
values ('USD', 'US dollar', '$', 2) on conflict (code) do nothing;
insert into public.organisation_memberships (organisation_id, user_id, status, joined_at)
values ('70000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', 'active', now());
insert into public.membership_roles (membership_id, role_id)
select m.id, r.id from public.organisation_memberships m join public.roles r on r.code = 'organisation.owner' and r.organisation_id is null
where m.organisation_id = '70000000-0000-0000-0000-000000000001';
insert into public.membership_scopes (membership_id, scope, scope_id)
select id, 'organisation', null from public.organisation_memberships where organisation_id = '70000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000001', true);

select is(
  public.create_tax_configuration_version(jsonb_build_object('organisationId', '70000000-0000-0000-0000-000000000001', 'code', 'VAT', 'name', 'Value added tax', 'taxType', 'vat', 'ratePercent', '18', 'effectiveFrom', '2026-08-06', 'sourceReference', 'Tax schedule')) is not null,
  true,
  'Organisation owner can create a tax configuration draft'
);
select lives_ok(
  $$select public.approve_tax_configuration_version(id) from public.tax_configuration_versions where organisation_id = '70000000-0000-0000-0000-000000000001' and code = 'VAT'$$,
  'Organisation owner can approve a tax configuration draft'
);
select is(
  (select approval_status from public.tax_configuration_versions where organisation_id = '70000000-0000-0000-0000-000000000001' and code = 'VAT'),
  'approved'::public.configuration_approval_status,
  'Approved tax configuration retains its versioned state'
);
select is(
  public.create_exchange_rate_version(jsonb_build_object('organisationId', '70000000-0000-0000-0000-000000000001', 'currencyCode', 'USD', 'effectiveOn', '2026-08-06', 'rate', '2565.25', 'sourceReference', 'Bank bulletin')) is not null,
  true,
  'Organisation owner can create a foreign-currency exchange-rate draft'
);

select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$select public.create_tax_configuration_version(jsonb_build_object('organisationId', '70000000-0000-0000-0000-000000000001', 'code', 'WHT', 'name', 'Withholding tax', 'taxType', 'withholding', 'ratePercent', '5', 'effectiveFrom', '2026-08-06', 'sourceReference', 'Tax schedule'))$$,
  '42501',
  'Organisation localisation management permission is required',
  'Unauthorised users cannot create tax configurations'
);

reset role;
select * from finish();

rollback;
