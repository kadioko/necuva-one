# Phase 2: Master Data

## Objective

Build the reusable, tenant-safe reference data on which accounting, purchasing, inventory, and sales will depend. Phase 2 deliberately does not post financial or stock transactions.

## Delivery Order

1. Localisation configuration: currencies, organisation exchange rates, and effective-dated tax versions.
2. Business parties: customer and supplier records, contacts, categories, and addresses. Implemented.
3. Item catalogue: products, services, categories, units of measure, conversions, and barcodes. Implemented.
4. Payment reference data: payment methods, bank accounts, and mobile-money accounts.
5. Controlled imports: templates, validation previews, duplicate detection, confirmation, and audit records.

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

## Deferred

Tax calculation, withholding allocation, payroll deductions, invoice rendering, and any ledger or stock posting remain deferred to their owning phases.
