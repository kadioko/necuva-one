# Phase 3: Accounting

## Objective

Build a company-scoped, auditable double-entry accounting core. Configuration must be stable before journals exist, and no report may derive from editable balances or bypass the central posting engine.

## Delivery Order

1. Accounting configuration: account groups, chart of accounts, and draft fiscal calendars. Implemented.
2. Journal preparation: atomic document numbering, balanced base-currency draft journals, and source references. Implemented. Attachments remain deferred until document storage is introduced.
3. Approval, posting, reversal, and fiscal-period controls with separate permissions and immutable posted entries.
4. Controlled opening balances through the same posting engine.
5. General-ledger inquiry, journal inquiry, trial balance, and drill-down to source entries.
6. Cashbook, settlement-account ledger mapping, bank statements, and reconciliation.
7. Accounts receivable, accounts payable, receipts, payments, and allocations.
8. Financial statements, foreign-exchange treatment, period close, and group consolidation foundations.

## Configuration Rules

- Account groups and chart accounts belong to a legal company and retain the organisation tenant key. Company-scoped RLS and commands enforce assigned scope.
- Account types are asset, liability, equity, income, and expense. Normal balance is generated from type: assets and expenses are debit-normal; liabilities, equity, and income are credit-normal.
- Every chart account belongs to a group of the same account type. Control accounts cannot accept manual postings; future subledgers will post to them only through controlled commands.
- Account and group codes are unique within a company. No statutory or industry-specific chart is hard-coded.
- Fiscal years start on the first day of a month, span twelve monthly periods, and cannot overlap within a company.
- Newly created fiscal years remain draft and all periods remain future. This slice does not open periods or permit postings.

## Draft Journal Rules

- A manual journal belongs to one organisation, legal company, branch, fiscal year, and fiscal period. The database derives the fiscal period from the journal date and rejects dates outside a draft/open year and future/open period.
- Preparation uses the legal company's base currency. Browser decimal strings are converted to integer minor units using platform currency precision, and PostgreSQL accepts minor-unit strings only.
- Every draft contains 2 to 200 lines, exactly one positive debit or credit per line, and equal positive totals. Accounts must be active, belong to the same company, permit manual posting, and not be control accounts.
- `GJ-YYYY-NNNNNN` numbers are allocated per company and fiscal year under a transaction lock. Allocation commits with the draft, and identifiers are never reused.
- Journal creation atomically writes the header, lines, totals, and one audit event. Authenticated users have no direct insert, update, or delete privilege on journal tables.
- `organisation.accounting.journals.prepare` resolves organisation, company, branch, and warehouse scopes to the target branch. Draft readers see only authorized branches.

## Deferred

There is no attachment, submission, approval, posting, reversal, ledger-entry, balance, opening-balance, period-close, reconciliation, tax-posting, or financial-report command in this slice. The journal status type reserves later workflow states, but only `draft` is reachable through an implemented command.
