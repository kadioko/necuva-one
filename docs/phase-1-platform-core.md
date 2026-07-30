# Phase 1 Platform Core Status

## Implemented

- Supabase Auth profiles and cookie-backed Next.js sessions.
- Organisation, company, branch, department, warehouse, membership, role, permission, scope, subscription, audit, and support-access schema.
- RLS tenant boundary with no implicit Necuva support access.
- One-time platform-owner bootstrap restricted by a server-only email allow-list.
- Atomic organisation provisioning: organisation, company, branch, owner membership, owner role/scope, implementation record, and audit event.
- Organisation-owner structure management for additional companies, branches, departments, and warehouses, with scoped permission checks and audit events.
- Email-based user invitations with server-side role and company, branch, warehouse, or organisation scope validation. Auth delivery failures and membership-finalisation failures are compensated and audited.
- Existing-user membership activation/deactivation and role assignment, with audit events.
- Permission-gated audit-trail search for organisation owners.
- CSV audit export with the same RLS permission check as the audit trail, optional action/date filters, a 5,000-event bound, and spreadsheet-formula neutralisation.
- Time-limited, reasoned support-access grants for approved platform staff, with audit records and revocation RPC support.
- Tenant lifecycle changes, subscription plan administration/assignment, implementation stage changes, granular company/branch/warehouse scopes, custom-role creation/assignment, and saved tenant context.
- Subscription plans can cap members, companies, branches, and warehouses; caps are enforced during assignment and the corresponding server-side resource mutations.
- Saved tenant context powers a scope-revalidated organisation dashboard with hierarchy counts, subscription state, and implementation stage.
- Control Centre forms, Zod validation, server actions, unit tests, pgTAP database tests, and CI wiring.

## Remaining in Phase 1

- End-to-end browser tests.

## Constraints

The database test suite requires a running local Supabase/Postgres environment. It is executed in CI, but local verification is unavailable until Docker Desktop's Linux engine is running.
