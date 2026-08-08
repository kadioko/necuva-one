# Phase 2: Master Data

## Objective

Build the reusable, tenant-safe reference data on which accounting, purchasing, inventory, and sales will depend. Phase 2 deliberately does not post financial or stock transactions.

## Delivery Order

1. Localisation configuration: currencies, organisation exchange rates, and effective-dated tax versions.
2. Business parties: customer and supplier records, contacts, categories, and addresses. Implemented.
3. Item catalogue: products, services, categories, units of measure, conversions, and barcodes. Implemented.
4. Payment reference data: payment methods, bank accounts, and mobile-money accounts. Implemented.
5. Controlled imports: templates, validation previews, duplicate detection, confirmation, and audit records. Implemented for business parties and catalogue items.

## Localisation Rules

- Currencies are platform-managed reference data. TZS is seeded, but no tax rate is hard-coded.
- Exchange rates and tax configurations belong to an organisation and are append-only versions with effective dates, source references, approval state, actor, and audit event.
- Ordinary members may read active tenant reference data through RLS. Only holders of the relevant organisation permissions can create a draft or approve a version.
- Future operational documents will resolve approved, effective versions at posting time; they will never recalculate historical documents from later configuration changes.

## Business Party Rules

- Parties belong to one organisation and can be a customer, supplier, or both without duplicating their identity.
- Categories, contacts, and addresses are tenant-owned and use composite organisation keys to prevent cross-tenant child references.
- An organisation permission governs all party mutations; ordinary active members may read party data under RLS.
- Contacts and addresses remain separate from the party record so later sales, purchasing, delivery, statements, and imports can select the appropriate record without overwriting the legal identity.

## Item Catalogue Rules

- Product and service identities belong to an organisation, use a canonical base unit, and have tenant-unique item codes.
- Units and categories are tenant-owned reference data. Unit conversions use positive PostgreSQL `numeric` factors and only connect compatible unit dimensions.
- Barcodes are separate tenant-unique records, allowing multiple scannable codes per item without overloading the item identifier.
- The catalogue has no editable quantity, stock cost, or valuation field. Future inventory movements will be the exclusive source of stock balances.

## Payment Reference Rules

- Payment methods, bank accounts, and mobile-money accounts belong to a legal company as well as its organisation; composite foreign keys prevent cross-tenant or cross-company references.
- Settlement-account reads and mutations require `organisation.payment_references.manage` within the member's assigned organisation, company, branch, or warehouse scope.
- Account identifiers are masked in the interface and audit payloads. Only authorised administrators can select the underlying reference records.
- One active default bank account and one active default mobile-money account may exist per company and currency. Providers and currencies are configurable rather than hard-coded for Tanzania.
- These records hold no balances, ledger mappings, payment transactions, reconciliation state, or provider credentials. Those belong to accounting and integration phases.

## Controlled Import Rules

- Versioned CSV templates define exact columns for business-party and catalogue-item imports. Files are parsed server-side with strict column counts and a 1 MB, 500-row synchronous limit.
- Every file is identified by a SHA-256 checksum and can be staged only once for an organisation and import type.
- Staging writes immutable raw rows, normalized previews, create/update operations, and row-level validation errors. Existing external or item codes are shown as updates; repeated codes within one file are invalid.
- Catalogue imports resolve active base-unit and optional category codes during staging. Party imports require external codes so updates remain deterministic.
- Confirmation requires both import permission and the target domain permission, is blocked while any row is invalid, and applies the complete batch in one database transaction through the existing audited domain commands.

## Status

Phase 2 is complete. Additional import targets can extend the same staging contract when their owning modules are implemented.

## Deferred

Tax calculation, withholding allocation, payroll deductions, invoice rendering, and any ledger or stock posting remain deferred to their owning phases.
