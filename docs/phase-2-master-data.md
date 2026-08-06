# Phase 2: Master Data

## Objective

Build the reusable, tenant-safe reference data on which accounting, purchasing, inventory, and sales will depend. Phase 2 deliberately does not post financial or stock transactions.

## Delivery Order

1. Localisation configuration: currencies, organisation exchange rates, and effective-dated tax versions.
2. Business parties: customer and supplier records, contacts, categories, and addresses.
3. Item catalogue: products, services, categories, units of measure, conversions, and barcodes.
4. Payment reference data: payment methods, bank accounts, and mobile-money accounts.
5. Controlled imports: templates, validation previews, duplicate detection, confirmation, and audit records.

## Localisation Rules

- Currencies are platform-managed reference data. TZS is seeded, but no tax rate is hard-coded.
- Exchange rates and tax configurations belong to an organisation and are append-only versions with effective dates, source references, approval state, actor, and audit event.
- Ordinary members may read active tenant reference data through RLS. Only holders of the relevant organisation permissions can create a draft or approve a version.
- Future operational documents will resolve approved, effective versions at posting time; they will never recalculate historical documents from later configuration changes.

## Deferred

Tax calculation, withholding allocation, payroll deductions, invoice rendering, and any ledger or stock posting remain deferred to their owning phases.
