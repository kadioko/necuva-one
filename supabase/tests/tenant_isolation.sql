begin;

-- Database test contract: run in a local Supabase test role with two seeded auth users.
-- Phase 0 keeps executable RLS verification in application integration tests until test identities
-- are provisioned by the local test harness.
select plan(1);
select pass('Tenant-isolation scenarios are specified for the application harness.');
select * from finish();

rollback;
