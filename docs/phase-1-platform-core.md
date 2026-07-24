# Phase 1 Platform Core Status

## Implemented

- Supabase Auth profiles and cookie-backed Next.js sessions.
- Organisation, company, branch, department, warehouse, membership, role, permission, scope, subscription, audit, and support-access schema.
- RLS tenant boundary with no implicit Necuva support access.
- One-time platform-owner bootstrap restricted by a server-only email allow-list.
- Atomic organisation provisioning: organisation, company, branch, owner membership, owner role/scope, implementation record, and audit event.
- Organisation-owner structure management for additional companies, branches, departments, and warehouses, with scoped permission checks and audit events.
- Existing-user membership activation/deactivation and system-role assignment, with audit events.
- Permission-gated audit-trail search for organisation owners.
- Time-limited, reasoned support-access grants for approved platform staff, with audit records and revocation RPC support.
- Control Centre forms, Zod validation, server actions, unit tests, pgTAP database tests, and CI wiring.

## Remaining in Phase 1

- User invitation and granular company/branch/warehouse scope administration.
- Permission management UI and custom-role workflow.
- Audit-log export and support-access grant listing/revocation screen.
- Subscription-plan administration and tenant suspension enforcement.
- Onboarding workflow, saved tenant context, dashboard data, and end-to-end browser tests.

## Constraints

The database test suite requires a running local Supabase/Postgres environment. It is executed in CI, but local verification is unavailable until Docker Desktop's Linux engine is running.
