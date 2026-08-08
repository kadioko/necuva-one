# Phase 3: Accounting

## Objective

Build a company-scoped, auditable double-entry accounting core. Configuration must be stable before journals exist, and no report may derive from editable balances or bypass the central posting engine.

## Delivery Order

1. Accounting configuration: account groups, chart of accounts, and draft fiscal calendars. Implemented.
2. Journal preparation: document numbering, balanced draft journals, source references, and attachments.
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

## Deferred

There are no journal, ledger-entry, balance, opening-balance, period-close, reconciliation, tax-posting, or financial-report commands in this slice. Those remain blocked until their delivery step is implemented and tested.
