begin;

select plan(9);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at) values
  ('00000000-0000-0000-0000-000000000000', '82000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'payments-owner@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '82000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'payments-manager@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '82000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'payments-outsider@example.test', 'not-used', now(), '{}', '{}', now(), now());
insert into public.organisations (id, legal_name, display_name) values ('92000000-0000-0000-0000-000000000001', 'Payment Tenant Limited', 'Payment Tenant');
insert into public.companies (id, organisation_id, legal_name) values
  ('93000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', 'Payment Company A'),
  ('93000000-0000-0000-0000-000000000002', '92000000-0000-0000-0000-000000000001', 'Payment Company B');
insert into public.organisation_memberships (id, organisation_id, user_id, status, joined_at) values
  ('94000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', '82000000-0000-0000-0000-000000000001', 'active', now()),
  ('94000000-0000-0000-0000-000000000002', '92000000-0000-0000-0000-000000000001', '82000000-0000-0000-0000-000000000002', 'active', now());
insert into public.membership_roles (membership_id, role_id)
select '94000000-0000-0000-0000-000000000001', id from public.roles where code = 'organisation.owner' and organisation_id is null;
insert into public.membership_scopes (membership_id, scope, scope_id) values ('94000000-0000-0000-0000-000000000001', 'organisation', null);
insert into public.roles (id, organisation_id, code, name, default_scope) values ('95000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', 'payments.manager', 'Payments Manager', 'company');
insert into public.role_permissions (role_id, permission_id) select '95000000-0000-0000-0000-000000000001', id from public.permissions where code = 'organisation.payment_references.manage';
insert into public.membership_roles (membership_id, role_id) values ('94000000-0000-0000-0000-000000000002', '95000000-0000-0000-0000-000000000001');
insert into public.membership_scopes (membership_id, scope, scope_id) values ('94000000-0000-0000-0000-000000000002', 'company', '93000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub', '82000000-0000-0000-0000-000000000001', true);
select is(public.upsert_payment_method(jsonb_build_object('organisationId', '92000000-0000-0000-0000-000000000001', 'companyId', '93000000-0000-0000-0000-000000000001', 'code', 'CASH', 'name', 'Cash', 'kind', 'cash', 'isActive', 'true')) is not null, true, 'Owner can create a payment method for company A');
select is(public.upsert_payment_method(jsonb_build_object('organisationId', '92000000-0000-0000-0000-000000000001', 'companyId', '93000000-0000-0000-0000-000000000002', 'code', 'BANK', 'name', 'Bank transfer', 'kind', 'bank_transfer', 'isActive', 'true')) is not null, true, 'Owner can create a payment method for company B');
select is(public.upsert_bank_account(jsonb_build_object('organisationId', '92000000-0000-0000-0000-000000000001', 'companyId', '93000000-0000-0000-0000-000000000001', 'code', 'BANK-TZS', 'name', 'Primary bank', 'bankName', 'NMB Bank', 'accountName', 'Payment Company A', 'accountNumber', '000123456789', 'currencyCode', 'TZS', 'isDefault', 'true', 'isActive', 'true')) is not null, true, 'Owner can create a bank account');
select is(public.upsert_mobile_money_account(jsonb_build_object('organisationId', '92000000-0000-0000-0000-000000000001', 'companyId', '93000000-0000-0000-0000-000000000001', 'code', 'MOBILE-TZS', 'name', 'Mobile collections', 'providerName', 'Provider', 'accountName', 'Payment Company A', 'phoneNumber', '+255712345678', 'currencyCode', 'TZS', 'isDefault', 'true', 'isActive', 'true')) is not null, true, 'Owner can create a mobile-money account');
select ok(not exists (select 1 from public.audit_events where organisation_id = '92000000-0000-0000-0000-000000000001' and (after_state::text like '%000123456789%' or after_state::text like '%+255712345678%')), 'Audit records do not contain full settlement identifiers');

select set_config('request.jwt.claim.sub', '82000000-0000-0000-0000-000000000002', true);
select is((select count(*) from public.payment_methods), 1::bigint, 'Company-scoped manager reads only assigned-company payment methods');
select lives_ok($$select public.upsert_payment_method(jsonb_build_object('organisationId', '92000000-0000-0000-0000-000000000001', 'companyId', '93000000-0000-0000-0000-000000000001', 'code', 'CARD', 'name', 'Card', 'kind', 'card', 'isActive', 'true'))$$, 'Company-scoped manager can manage the assigned company');
select throws_ok($$select public.upsert_payment_method(jsonb_build_object('organisationId', '92000000-0000-0000-0000-000000000001', 'companyId', '93000000-0000-0000-0000-000000000002', 'code', 'DENIED', 'name', 'Denied', 'kind', 'other', 'isActive', 'true'))$$, '42501', 'Company payment-reference management permission is required', 'Company-scoped manager cannot manage another company');

select set_config('request.jwt.claim.sub', '82000000-0000-0000-0000-000000000003', true);
select throws_ok($$select public.upsert_payment_method(jsonb_build_object('organisationId', '92000000-0000-0000-0000-000000000001', 'companyId', '93000000-0000-0000-0000-000000000001', 'code', 'DENIED', 'name', 'Denied', 'kind', 'other', 'isActive', 'true'))$$, '42501', 'Company payment-reference management permission is required', 'Outsider cannot manage payment references');

reset role;
select * from finish();

rollback;
