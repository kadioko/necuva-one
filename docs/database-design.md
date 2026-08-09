# Database Design

## Core hierarchy

`platform -> organisation -> company -> branch -> department / warehouse`

```mermaid
erDiagram
  PROFILES ||--o{ ORGANISATION_MEMBERSHIPS : joins
  ORGANISATIONS ||--o{ ORGANISATION_MEMBERSHIPS : has
  ORGANISATIONS ||--o{ COMPANIES : owns
  COMPANIES ||--o{ BRANCHES : contains
  BRANCHES ||--o{ DEPARTMENTS : groups
  BRANCHES ||--o{ WAREHOUSES : operates
  ORGANISATION_MEMBERSHIPS ||--o{ MEMBERSHIP_ROLES : receives
  ROLES ||--o{ MEMBERSHIP_ROLES : assigns
  ROLES ||--o{ ROLE_PERMISSIONS : grants
  PERMISSIONS ||--o{ ROLE_PERMISSIONS : defines
  ORGANISATIONS ||--o{ SUPPORT_ACCESS_GRANTS : authorises
  ORGANISATIONS ||--o{ AUDIT_EVENTS : records
```

`profiles` is keyed by `auth.users.id`. `organisation_memberships` establishes a user's tenant membership. Role assignments and scope assignments determine the member's effective permissions.

## Rules

- Every tenant-owned business record includes `organisation_id`.
- Company, branch, department and warehouse records include their parent IDs and composite unique keys that support tenant-consistent foreign keys.
- Timestamps use `timestamptz`; IDs use UUIDs; money will use integer minor units or documented `numeric` scale, never JavaScript floating point.
- Tenant state is explicit. Suspended organisations cannot create new transactional records in later phases.
- Audit records are append-only to ordinary users.

## Platform provisioning tables

The baseline includes organisations, companies, branches, departments, warehouses, profiles, memberships, roles, permissions, role permissions, member roles, member scopes, platform role assignments, support access grants, audit events, modules, plans, plan limits, plan modules, subscriptions, implementation projects, shared currencies, organisation exchange-rate versions, tax-configuration versions, business-party categories, business parties, party contacts, party addresses, item categories, units of measure, unit conversions, catalogue items, item barcodes, payment methods, bank accounts, mobile-money accounts, master-data import batches, staged import rows, account groups, chart accounts, fiscal years, fiscal periods, accounting-journal sequences, journal headers, and journal lines.

`platform_role_assignments` is separate from tenant membership because platform staff must not receive tenant membership merely to administer the platform. `provision_organisation(jsonb)` is a security-definer function that checks a platform permission internally and atomically creates the tenant root, first company, first branch, owner membership/scope/role, implementation record, and audit event.

## Current Phase 1 commands

Audited, permission-checked commands now cover tenant lifecycle, subscription plans and assignment, implementation stages, structure creation, membership/scope assignment, custom-role creation, support-access grant/revocation, and audit-trail visibility. Assigned plan limits are checked inside resource-creation and membership commands rather than only in the user interface.

## Phase 2 Localisation Foundation

`currencies` is platform-managed reference data. `organisation_exchange_rate_versions` and `tax_configuration_versions` are tenant-owned, RLS-protected append-only configuration versions. Both carry effective dates, source references, draft/approved/retired state, actor references, and audit events. Approval retires an approved record for the same effective key before it promotes the selected draft, preserving historical versions without hard-coding statutory rates.

`business_parties` stores a tenant's customer, supplier, or shared party identity. Categories, contacts, and addresses each duplicate `organisation_id` and use composite foreign keys to the party, preventing cross-tenant child records at the database boundary. Primary contact and primary address selections are constrained with partial unique indexes.

## Phase 2 Item Catalogue

`catalog_items` separates product and service identity from future inventory balances. Each item has a tenant-scoped code, category, and base unit; products may opt into future inventory tracking, while services cannot. Categories, units, conversions, and barcodes all carry `organisation_id`; composite foreign keys prevent cross-tenant links, compatible unit dimensions are checked in the command, and a partial unique index ensures at most one primary barcode per item.

## Phase 2 Payment References

`payment_methods`, `bank_accounts`, and `mobile_money_accounts` are company-owned configuration records with an explicit tenant key. Their composite company foreign keys prevent cross-tenant ownership, while `private.has_company_permission` applies organisation and nested company scope to both RLS reads and RPC mutations. Partial unique indexes permit only one active default settlement account of each account type per company and currency. Account identifiers are deliberately excluded from audit payloads except for their final four characters.

## Phase 2 Controlled Imports

`master_data_imports` records the tenant, target type, source checksum, row counts, lifecycle, and actors. `master_data_import_rows` retains each raw row, normalized data, proposed create/update operation, and validation errors. Staging and confirmation are security-definer commands; confirmation locks the batch, rejects invalid or already-confirmed work, and invokes existing domain commands atomically. Direct table writes are not granted to authenticated users.

## Phase 3 Accounting Configuration

`account_groups` and `chart_accounts` are legal-company records protected by company-scope RLS and composite tenant foreign keys. Group/account type consistency is enforced by a composite foreign key, and chart-account normal balance is a generated value rather than editable state. `fiscal_years` and `fiscal_periods` use date-guard triggers to prevent overlap; the creation command atomically creates a draft year and twelve future monthly periods.

## Phase 3 Journal Preparation

`accounting_journals` duplicates organisation, company, and branch keys so composite foreign keys and branch-aware RLS enforce ownership at every read. `accounting_journal_lines` carries the same keys, references a same-company chart account, and constrains each row to exactly one positive debit or credit. Header totals are positive, equal integer minor units. `accounting_journal_sequences` allocates `GJ` numbers per company and fiscal year inside the journal transaction. The only current mutation is `create_draft_journal(jsonb)`; direct client writes and workflow transitions are unavailable.
