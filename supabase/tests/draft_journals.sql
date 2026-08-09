begin;

select plan(20);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at) values
  ('00000000-0000-0000-0000-000000000000', '85000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'journal-owner@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '85000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'journal-preparer@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '85000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'journal-outsider@example.test', 'not-used', now(), '{}', '{}', now(), now());

insert into public.organisations (id, legal_name, display_name) values
  ('a7000000-0000-0000-0000-000000000001', 'Journal Tenant Limited', 'Journal Tenant');
insert into public.companies (id, organisation_id, legal_name, currency_code) values
  ('a8000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-000000000001', 'Journal Company', 'TZS');
insert into public.branches (id, organisation_id, company_id, code, name) values
  ('a9000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000001', 'DAR', 'Dar es Salaam'),
  ('a9000000-0000-0000-0000-000000000002', 'a7000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000001', 'ARU', 'Arusha');

insert into public.organisation_memberships (id, organisation_id, user_id, status, joined_at) values
  ('aa000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-000000000001', '85000000-0000-0000-0000-000000000001', 'active', now()),
  ('aa000000-0000-0000-0000-000000000002', 'a7000000-0000-0000-0000-000000000001', '85000000-0000-0000-0000-000000000002', 'active', now());
insert into public.membership_roles (membership_id, role_id)
select 'aa000000-0000-0000-0000-000000000001', id from public.roles where code = 'organisation.owner' and organisation_id is null;
insert into public.membership_scopes (membership_id, scope, scope_id) values
  ('aa000000-0000-0000-0000-000000000001', 'organisation', null);

insert into public.roles (id, organisation_id, code, name, default_scope) values
  ('ab000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-000000000001', 'journal.preparer', 'Journal Preparer', 'branch');
insert into public.role_permissions (role_id, permission_id)
select 'ab000000-0000-0000-0000-000000000001', id from public.permissions where code = 'organisation.accounting.journals.prepare';
insert into public.membership_roles (membership_id, role_id) values
  ('aa000000-0000-0000-0000-000000000002', 'ab000000-0000-0000-0000-000000000001');
insert into public.membership_scopes (membership_id, scope, scope_id) values
  ('aa000000-0000-0000-0000-000000000002', 'branch', 'a9000000-0000-0000-0000-000000000001');

insert into public.account_groups (id, organisation_id, company_id, code, name, account_type) values
  ('ac000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000001', '1.10', 'Current assets', 'asset'),
  ('ac000000-0000-0000-0000-000000000002', 'a7000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000001', '4.10', 'Revenue', 'income');
insert into public.chart_accounts (id, organisation_id, company_id, group_id, code, name, account_type, is_control_account, allow_manual_posting, created_by) values
  ('ad000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000001', 'ac000000-0000-0000-0000-000000000001', '1100', 'Cash at bank', 'asset', false, true, '85000000-0000-0000-0000-000000000001'),
  ('ad000000-0000-0000-0000-000000000002', 'a7000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000001', 'ac000000-0000-0000-0000-000000000002', '4100', 'Service revenue', 'income', false, true, '85000000-0000-0000-0000-000000000001'),
  ('ad000000-0000-0000-0000-000000000003', 'a7000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000001', 'ac000000-0000-0000-0000-000000000001', '1200', 'Receivables control', 'asset', true, false, '85000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub', '85000000-0000-0000-0000-000000000001', true);
select is(public.create_fiscal_year(jsonb_build_object('organisationId', 'a7000000-0000-0000-0000-000000000001', 'companyId', 'a8000000-0000-0000-0000-000000000001', 'name', '2026/2027', 'startDate', '2026-07-01')) is not null, true, 'Owner creates the journal fiscal calendar');

select is(public.create_draft_journal(jsonb_build_object(
  'organisationId', 'a7000000-0000-0000-0000-000000000001', 'companyId', 'a8000000-0000-0000-0000-000000000001', 'branchId', 'a9000000-0000-0000-0000-000000000001',
  'journalDate', '2026-08-09', 'description', 'Cash sale', 'sourceReference', 'SALE-001',
  'lines', jsonb_build_array(
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000001', 'debitMinor', '25000', 'creditMinor', '0'),
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000002', 'debitMinor', '0', 'creditMinor', '25000')
  )
)) is not null, true, 'Owner creates a balanced draft journal');
select is((select journal_number from public.accounting_journals where source_reference = 'SALE-001'), 'GJ-2026-000001', 'First journal number is allocated for the fiscal year');
select is((select total_debit_minor from public.accounting_journals where source_reference = 'SALE-001'), 25000::bigint, 'Draft stores an exact minor-unit total');
select is((select count(*) from public.accounting_journal_lines where journal_id = (select id from public.accounting_journals where source_reference = 'SALE-001')), 2::bigint, 'Draft lines are written atomically');
select is((select status from public.accounting_journals where source_reference = 'SALE-001'), 'draft'::public.accounting_journal_status, 'Preparation creates only draft status');
select is((select currency_code from public.accounting_journals where source_reference = 'SALE-001'), 'TZS'::bpchar, 'Journal currency is derived from the company');

select is(public.create_draft_journal(jsonb_build_object(
  'organisationId', 'a7000000-0000-0000-0000-000000000001', 'companyId', 'a8000000-0000-0000-0000-000000000001', 'branchId', 'a9000000-0000-0000-0000-000000000002',
  'journalDate', '2026-08-10', 'description', 'Arusha cash sale', 'sourceReference', 'SALE-002',
  'lines', jsonb_build_array(
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000001', 'debitMinor', '30000', 'creditMinor', '0'),
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000002', 'debitMinor', '0', 'creditMinor', '30000')
  )
)) is not null, true, 'Owner creates a draft for another branch');
select is((select journal_number from public.accounting_journals where source_reference = 'SALE-002'), 'GJ-2026-000002', 'Journal numbering increments atomically');

select throws_ok($$select public.create_draft_journal(jsonb_build_object(
  'organisationId', 'a7000000-0000-0000-0000-000000000001', 'companyId', 'a8000000-0000-0000-0000-000000000001', 'branchId', 'a9000000-0000-0000-0000-000000000001',
  'journalDate', '2026-08-11', 'description', 'Unbalanced', 'sourceReference', 'BAD-001',
  'lines', jsonb_build_array(
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000001', 'debitMinor', '100', 'creditMinor', '0'),
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000002', 'debitMinor', '0', 'creditMinor', '99')
  )
))$$, '23514', 'Draft journal debits and credits must balance', 'Unbalanced drafts are rejected');
select throws_ok($$select public.create_draft_journal(jsonb_build_object(
  'organisationId', 'a7000000-0000-0000-0000-000000000001', 'companyId', 'a8000000-0000-0000-0000-000000000001', 'branchId', 'a9000000-0000-0000-0000-000000000001',
  'journalDate', '2026-08-11', 'description', 'Control account', 'sourceReference', 'BAD-002',
  'lines', jsonb_build_array(
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000003', 'debitMinor', '100', 'creditMinor', '0'),
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000002', 'debitMinor', '0', 'creditMinor', '100')
  )
))$$, '22023', 'Journal line 1 account is unavailable for manual posting', 'Control accounts are rejected');
select throws_ok($$select public.create_draft_journal(jsonb_build_object(
  'organisationId', 'a7000000-0000-0000-0000-000000000001', 'companyId', 'a8000000-0000-0000-0000-000000000001', 'branchId', 'a9000000-0000-0000-0000-000000000001',
  'journalDate', '2030-08-11', 'description', 'Outside period', 'sourceReference', 'BAD-003',
  'lines', jsonb_build_array(
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000001', 'debitMinor', '100', 'creditMinor', '0'),
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000002', 'debitMinor', '0', 'creditMinor', '100')
  )
))$$, '22023', 'Journal date is outside an available fiscal period', 'Dates outside the fiscal calendar are rejected');

select set_config('request.jwt.claim.sub', '85000000-0000-0000-0000-000000000002', true);
select is((select count(*) from public.list_journal_preparation_branches('a7000000-0000-0000-0000-000000000001')), 1::bigint, 'Branch preparer receives only the assigned branch');
select is(public.create_draft_journal(jsonb_build_object(
  'organisationId', 'a7000000-0000-0000-0000-000000000001', 'companyId', 'a8000000-0000-0000-0000-000000000001', 'branchId', 'a9000000-0000-0000-0000-000000000001',
  'journalDate', '2026-08-12', 'description', 'Assigned branch', 'sourceReference', 'SALE-003',
  'lines', jsonb_build_array(
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000001', 'debitMinor', '500', 'creditMinor', '0'),
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000002', 'debitMinor', '0', 'creditMinor', '500')
  )
)) is not null, true, 'Branch preparer creates a draft in the assigned branch');
select throws_ok($$select public.create_draft_journal(jsonb_build_object(
  'organisationId', 'a7000000-0000-0000-0000-000000000001', 'companyId', 'a8000000-0000-0000-0000-000000000001', 'branchId', 'a9000000-0000-0000-0000-000000000002',
  'journalDate', '2026-08-12', 'description', 'Other branch', 'sourceReference', 'BAD-004',
  'lines', jsonb_build_array(
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000001', 'debitMinor', '500', 'creditMinor', '0'),
    jsonb_build_object('accountId', 'ad000000-0000-0000-0000-000000000002', 'debitMinor', '0', 'creditMinor', '500')
  )
))$$, '42501', 'Branch journal preparation permission is required', 'Branch preparer cannot create in another branch');
select is((select count(*) from public.accounting_journals), 2::bigint, 'Branch RLS hides journals from other branches');

select set_config('request.jwt.claim.sub', '85000000-0000-0000-0000-000000000003', true);
select is((select count(*) from public.list_journal_preparation_branches('a7000000-0000-0000-0000-000000000001')), 0::bigint, 'Outsider receives no preparation branches');
select throws_ok($$select public.create_draft_journal(jsonb_build_object(
  'organisationId', 'a7000000-0000-0000-0000-000000000001', 'companyId', 'a8000000-0000-0000-0000-000000000001', 'branchId', 'a9000000-0000-0000-0000-000000000001',
  'journalDate', '2026-08-12', 'description', 'Denied', 'sourceReference', 'BAD-005', 'lines', '[]'::jsonb
))$$, '42501', 'Branch journal preparation permission is required', 'Outsider cannot create a journal');
select is(has_table_privilege('authenticated', 'public.accounting_journals', 'insert'), false, 'Authenticated clients have no direct journal insert privilege');
select set_config('request.jwt.claim.sub', '85000000-0000-0000-0000-000000000001', true);
select is((select count(*) from public.audit_events where action = 'draft_journal_created'), 3::bigint, 'Every created draft has an audit event');

reset role;
select * from finish();

rollback;
