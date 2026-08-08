# Tenant Isolation

## Tenant boundary

The organisation is the customer tenant. A client-provided organisation ID is never sufficient authority. PostgreSQL derives access from `auth.uid()` and active membership records.

## RLS policy model

All tenant tables enable and force Row Level Security. General reference tables require `private.is_active_organisation_member(organisation_id)`; sensitive or administrative tables can require a narrower permission policy. Company payment references and accounting configuration use `private.has_company_permission` so organisation-, company-, branch-, and warehouse-scoped role assignments resolve to the correct legal company. Child tables additionally verify organisation-consistent parent relationships through composite foreign keys and constraints. Privileged database functions use a fixed `search_path`, perform their own actor and scope checks, and expose only required operations.

## Support access

Necuva staff receive no implied tenant visibility. Temporary access requires an active grant containing a reason, start time, expiry time, grantor and grantee. Grants are revocable and audited. Phase 0 stores the model and enforces the absence of default support access.

Phase 1 implements time-limited grants, revocation, participant/administrator visibility, and audit events. Support access is limited to seven days per grant.
