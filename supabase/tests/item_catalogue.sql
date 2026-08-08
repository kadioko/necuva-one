begin;

select plan(5);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at) values
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'catalogue-owner@example.test', 'not-used', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'catalogue-outsider@example.test', 'not-used', now(), '{}', '{}', now(), now());
insert into public.organisations (id, legal_name, display_name) values ('91000000-0000-0000-0000-000000000001', 'Catalogue Tenant Limited', 'Catalogue Tenant');
insert into public.organisation_memberships (organisation_id, user_id, status, joined_at) values ('91000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', 'active', now());
insert into public.membership_roles (membership_id, role_id)
select m.id, r.id from public.organisation_memberships m join public.roles r on r.code = 'organisation.owner' and r.organisation_id is null
where m.organisation_id = '91000000-0000-0000-0000-000000000001';
insert into public.membership_scopes (membership_id, scope, scope_id)
select id, 'organisation', null from public.organisation_memberships where organisation_id = '91000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
select is(public.create_item_category(jsonb_build_object('organisationId', '91000000-0000-0000-0000-000000000001', 'code', 'RAW', 'name', 'Raw materials')) is not null, true, 'Organisation owner can create an item category');
select is(public.create_unit_of_measure(jsonb_build_object('organisationId', '91000000-0000-0000-0000-000000000001', 'code', 'KG', 'name', 'Kilogram', 'dimension', 'weight', 'decimalPlaces', '3')) is not null, true, 'Organisation owner can create a unit');
select lives_ok($$select public.upsert_catalog_item(jsonb_build_object('organisationId', '91000000-0000-0000-0000-000000000001', 'categoryId', (select id from public.item_categories where code = 'RAW'), 'baseUnitId', (select id from public.units_of_measure where code = 'KG'), 'itemType', 'product', 'code', 'RICE', 'name', 'Rice', 'tracksInventory', 'true', 'isActive', 'true'))$$, 'Organisation owner can create a catalogue item');
select lives_ok($$select public.add_catalog_item_barcode(jsonb_build_object('organisationId', '91000000-0000-0000-0000-000000000001', 'itemId', (select id from public.catalog_items where code = 'RICE'), 'barcode', '1234567890123', 'symbology', 'ean_13', 'isPrimary', 'true'))$$, 'Organisation owner can add an item barcode');

select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000002', true);
select throws_ok($$select public.create_unit_of_measure(jsonb_build_object('organisationId', '91000000-0000-0000-0000-000000000001', 'code', 'DENIED', 'name', 'Denied', 'dimension', 'count', 'decimalPlaces', '0'))$$, '42501', 'Organisation catalogue management permission is required', 'Unauthorised users cannot manage the catalogue');

reset role;
select * from finish();

rollback;
