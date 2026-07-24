# Tenant Isolation

## Tenant boundary

The organisation is the customer tenant. A client-provided organisation ID is never sufficient authority. PostgreSQL derives access from `auth.uid()` and active membership records.

## RLS policy model

All tenant tables enable and force Row Level Security. A policy permits a row only when `private.is_active_organisation_member(organisation_id)` is true. Child tables additionally verify the organisation-consistent parent relationship through foreign keys and constraints. Privileged database functions use a fixed `search_path`, perform their own actor and scope checks, and expose only required operations.

## Support access

Necuva staff receive no implied tenant visibility. Temporary access requires an active grant containing a reason, start time, expiry time, grantor and grantee. Grants are revocable and audited. Phase 0 stores the model and enforces the absence of default support access.
