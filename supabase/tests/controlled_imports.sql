begin;

select plan(12);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at) values
  ('00000000-0000-0000-0000-000000000000', '83000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'imports-owner@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '83000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'imports-outsider@example.test', 'not-used', now(), '{}', '{}', now(), now());
insert into public.organisations (id, legal_name, display_name) values ('96000000-0000-0000-0000-000000000001', 'Import Tenant Limited', 'Import Tenant');
insert into public.organisation_memberships (organisation_id, user_id, status, joined_at) values ('96000000-0000-0000-0000-000000000001', '83000000-0000-0000-0000-000000000001', 'active', now());
insert into public.membership_roles (membership_id, role_id)
select m.id, r.id from public.organisation_memberships m join public.roles r on r.code = 'organisation.owner' and r.organisation_id is null
where m.organisation_id = '96000000-0000-0000-0000-000000000001';
insert into public.membership_scopes (membership_id, scope, scope_id)
select id, 'organisation', null from public.organisation_memberships where organisation_id = '96000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', '83000000-0000-0000-0000-000000000001', true);
do $$ begin
  perform public.upsert_business_party(jsonb_build_object('organisationId', '96000000-0000-0000-0000-000000000001', 'partyType', 'customer', 'externalCode', 'ACME', 'displayName', 'Old Acme Name', 'isActive', 'true'));
end $$;

select is(
  public.stage_master_data_import(jsonb_build_object(
    'organisationId', '96000000-0000-0000-0000-000000000001', 'importType', 'business_parties', 'fileName', 'parties.csv', 'fileChecksum', repeat('a', 64),
    'rows', jsonb_build_array(
      jsonb_build_object('rowNumber', 2, 'data', jsonb_build_object('externalCode', 'ACME', 'displayName', 'Acme Limited', 'partyType', 'customer', 'email', 'accounts@acme.test', 'isActive', 'true')),
      jsonb_build_object('rowNumber', 3, 'data', jsonb_build_object('externalCode', 'NEW-SUPPLIER', 'displayName', 'New Supplier', 'partyType', 'supplier', 'isActive', 'true'))
    )
  )) is not null,
  true,
  'Owner can stage a party import'
);
select is((select create_rows from public.master_data_imports where file_checksum = repeat('a', 64)), 1, 'Preview counts one create');
select is((select update_rows from public.master_data_imports where file_checksum = repeat('a', 64)), 1, 'Preview detects one existing-code update');
select is((select invalid_rows from public.master_data_imports where file_checksum = repeat('a', 64)), 0, 'Valid party import has no invalid rows');
select is(public.confirm_master_data_import((select id from public.master_data_imports where file_checksum = repeat('a', 64))), 2, 'Confirmation applies the full batch');
select is((select display_name from public.business_parties where organisation_id = '96000000-0000-0000-0000-000000000001' and external_code = 'ACME'), 'Acme Limited', 'Confirmation updates the existing party');
select ok(exists (select 1 from public.audit_events where organisation_id = '96000000-0000-0000-0000-000000000001' and action = 'master_data_import_confirmed'), 'Confirmation writes a batch audit event');

select is(
  public.stage_master_data_import(jsonb_build_object(
    'organisationId', '96000000-0000-0000-0000-000000000001', 'importType', 'catalog_items', 'fileName', 'items.csv', 'fileChecksum', repeat('b', 64),
    'rows', jsonb_build_array(
      jsonb_build_object('rowNumber', 2, 'data', jsonb_build_object('code', 'RICE', 'name', 'Rice', 'itemType', 'product', 'baseUnitCode', 'MISSING', 'tracksInventory', 'true', 'isActive', 'true')),
      jsonb_build_object('rowNumber', 3, 'data', jsonb_build_object('code', 'RICE', 'name', 'Duplicate Rice', 'itemType', 'product', 'baseUnitCode', 'MISSING', 'tracksInventory', 'true', 'isActive', 'true'))
    )
  )) is not null,
  true,
  'Owner can stage an invalid catalogue import for review'
);
select is((select invalid_rows from public.master_data_imports where file_checksum = repeat('b', 64)), 2, 'Invalid catalogue rows are counted');
select ok(exists (select 1 from public.master_data_import_rows where import_id = (select id from public.master_data_imports where file_checksum = repeat('b', 64)) and row_number = 3 and 'Item code is duplicated within this file.' = any(validation_errors)), 'Within-file duplicate codes are reported');
select throws_ok($$select public.confirm_master_data_import((select id from public.master_data_imports where file_checksum = repeat('b', 64)))$$, '22023', 'Only a valid staged import can be confirmed', 'Invalid imports cannot be confirmed');

select set_config('request.jwt.claim.sub', '83000000-0000-0000-0000-000000000002', true);
select throws_ok($$select public.stage_master_data_import(jsonb_build_object('organisationId', '96000000-0000-0000-0000-000000000001', 'importType', 'business_parties', 'fileName', 'denied.csv', 'fileChecksum', repeat('c', 64), 'rows', jsonb_build_array(jsonb_build_object('rowNumber', 2, 'data', jsonb_build_object('externalCode', 'DENIED', 'displayName', 'Denied', 'partyType', 'customer', 'isActive', 'true')))))$$, '42501', 'Organisation import management permission is required', 'Outsiders cannot stage imports');

reset role;
select * from finish();

rollback;
