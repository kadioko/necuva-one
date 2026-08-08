begin;

select plan(12);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at) values
  ('00000000-0000-0000-0000-000000000000', '84000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'accounting-owner@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '84000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'accounting-manager@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '84000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'accounting-outsider@example.test', 'not-used', now(), '{}', '{}', now(), now());
insert into public.organisations (id, legal_name, display_name) values ('97000000-0000-0000-0000-000000000001', 'Accounting Tenant Limited', 'Accounting Tenant');
insert into public.companies (id, organisation_id, legal_name) values
  ('98000000-0000-0000-0000-000000000001', '97000000-0000-0000-0000-000000000001', 'Accounting Company A'),
  ('98000000-0000-0000-0000-000000000002', '97000000-0000-0000-0000-000000000001', 'Accounting Company B');
insert into public.organisation_memberships (id, organisation_id, user_id, status, joined_at) values
  ('99000000-0000-0000-0000-000000000001', '97000000-0000-0000-0000-000000000001', '84000000-0000-0000-0000-000000000001', 'active', now()),
  ('99000000-0000-0000-0000-000000000002', '97000000-0000-0000-0000-000000000001', '84000000-0000-0000-0000-000000000002', 'active', now());
insert into public.membership_roles (membership_id, role_id)
select '99000000-0000-0000-0000-000000000001', id from public.roles where code = 'organisation.owner' and organisation_id is null;
insert into public.membership_scopes (membership_id, scope, scope_id) values ('99000000-0000-0000-0000-000000000001', 'organisation', null);
insert into public.roles (id, organisation_id, code, name, default_scope) values ('9a000000-0000-0000-0000-000000000001', '97000000-0000-0000-0000-000000000001', 'accounting.configurator', 'Accounting Configurator', 'company');
insert into public.role_permissions (role_id, permission_id) select '9a000000-0000-0000-0000-000000000001', id from public.permissions where code = 'organisation.accounting.configure';
insert into public.membership_roles (membership_id, role_id) values ('99000000-0000-0000-0000-000000000002', '9a000000-0000-0000-0000-000000000001');
insert into public.membership_scopes (membership_id, scope, scope_id) values ('99000000-0000-0000-0000-000000000002', 'company', '98000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub', '84000000-0000-0000-0000-000000000001', true);
select is(public.create_account_group(jsonb_build_object('organisationId', '97000000-0000-0000-0000-000000000001', 'companyId', '98000000-0000-0000-0000-000000000001', 'code', '1.10', 'name', 'Current assets', 'accountType', 'asset')) is not null, true, 'Owner creates a company A account group');
select is(public.create_account_group(jsonb_build_object('organisationId', '97000000-0000-0000-0000-000000000001', 'companyId', '98000000-0000-0000-0000-000000000002', 'code', '1.10', 'name', 'Current assets', 'accountType', 'asset')) is not null, true, 'Owner creates a company B account group');
select is(public.upsert_chart_account(jsonb_build_object('organisationId', '97000000-0000-0000-0000-000000000001', 'companyId', '98000000-0000-0000-0000-000000000001', 'groupId', (select id from public.account_groups where company_id = '98000000-0000-0000-0000-000000000001' and code = '1.10'), 'code', '1100', 'name', 'Cash at bank', 'accountType', 'asset', 'isControlAccount', 'false', 'allowManualPosting', 'true', 'isActive', 'true')) is not null, true, 'Owner creates a chart account');
select is((select normal_balance from public.chart_accounts where company_id = '98000000-0000-0000-0000-000000000001' and code = '1100'), 'debit'::public.account_normal_balance, 'Asset normal balance is derived as debit');
select throws_ok($$select public.upsert_chart_account(jsonb_build_object('organisationId', '97000000-0000-0000-0000-000000000001', 'companyId', '98000000-0000-0000-0000-000000000001', 'groupId', (select id from public.account_groups where company_id = '98000000-0000-0000-0000-000000000001' and code = '1.10'), 'code', '2100', 'name', 'Invalid liability', 'accountType', 'liability', 'isControlAccount', 'false', 'allowManualPosting', 'true', 'isActive', 'true'))$$, '22023', 'Chart account input is invalid', 'Account and group types cannot disagree');
select is(public.create_fiscal_year(jsonb_build_object('organisationId', '97000000-0000-0000-0000-000000000001', 'companyId', '98000000-0000-0000-0000-000000000001', 'name', '2026/2027', 'startDate', '2026-07-01')) is not null, true, 'Owner creates a draft fiscal year');
select is((select count(*) from public.fiscal_periods where company_id = '98000000-0000-0000-0000-000000000001'), 12::bigint, 'Fiscal year creates twelve monthly periods');
select throws_ok($$select public.create_fiscal_year(jsonb_build_object('organisationId', '97000000-0000-0000-0000-000000000001', 'companyId', '98000000-0000-0000-0000-000000000001', 'name', 'Overlapping', 'startDate', '2027-01-01'))$$, '23P01', 'Fiscal years cannot overlap for a company', 'Overlapping fiscal years are rejected');

select set_config('request.jwt.claim.sub', '84000000-0000-0000-0000-000000000002', true);
select is((select count(*) from public.account_groups), 1::bigint, 'Company-scoped configurator reads only assigned-company groups');
select lives_ok($$select public.create_account_group(jsonb_build_object('organisationId', '97000000-0000-0000-0000-000000000001', 'companyId', '98000000-0000-0000-0000-000000000001', 'code', '1.20', 'name', 'Non-current assets', 'accountType', 'asset'))$$, 'Company-scoped configurator manages the assigned company');
select throws_ok($$select public.create_account_group(jsonb_build_object('organisationId', '97000000-0000-0000-0000-000000000001', 'companyId', '98000000-0000-0000-0000-000000000002', 'code', '1.20', 'name', 'Denied group', 'accountType', 'asset'))$$, '42501', 'Company accounting configuration permission is required', 'Company-scoped configurator cannot manage another company');

select set_config('request.jwt.claim.sub', '84000000-0000-0000-0000-000000000003', true);
select throws_ok($$select public.create_fiscal_year(jsonb_build_object('organisationId', '97000000-0000-0000-0000-000000000001', 'companyId', '98000000-0000-0000-0000-000000000001', 'name', 'Denied', 'startDate', '2030-01-01'))$$, '42501', 'Company accounting configuration permission is required', 'Outsider cannot configure accounting');

reset role;
select * from finish();

rollback;
