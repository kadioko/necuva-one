# Phase 1 Platform Core Status

## Implemented

- Supabase Auth profiles and cookie-backed Next.js sessions.
- Organisation, company, branch, department, warehouse, membership, role, permission, scope, subscription, audit, and support-access schema.
- RLS tenant boundary with no implicit Necuva support access.
- One-time platform-owner bootstrap restricted by a server-only email allow-list.
- Atomic organisation provisioning: organisation, company, branch, owner membership, owner role/scope, implementation record, and audit event.
- Control Centre forms, Zod validation, server actions, unit tests, pgTAP database tests, and CI wiring.

## Remaining in Phase 1

- Company, branch, department, and warehouse management commands and screens.
- User invitation, deactivation, membership assignment, and scoped role administration.
- Permission management UI and custom-role workflow.
- Audit-log search/export and customer-visible support-access management.
- Subscription-plan administration and tenant suspension enforcement.
- Onboarding workflow, saved tenant context, dashboard data, and end-to-end browser tests.

## Constraints

The database test suite requires a running local Supabase/Postgres environment. It is executed in CI, but local verification is unavailable until Docker Desktop's Linux engine is running.
