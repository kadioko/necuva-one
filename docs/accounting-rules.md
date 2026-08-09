# Accounting Rules

Accounting implementation must use double-entry, immutable posted journals, atomic database posting, source documents, explicit document states, reversal-based correction, auditable creator/approver information, and integer-minor-unit or documented-decimal money values.

No module may create ledger entries independently. A central posting service will document and enforce treatments for sales, receipts, purchases, payments, returns, expenses, payroll, assets, depreciation and production.

Current status: company-scoped account groups, chart accounts, draft fiscal years, and twelve-period calendars are implemented. Normal balance is derived from account type, control accounts block manual posting, and fiscal calendars cannot overlap. Balanced manual journal drafts are also implemented with branch-aware preparation permission, base-currency integer minor units, database-derived periods, atomic fiscal-year numbering, source references, and audit events.

Draft journals are documents, not ledger entries. No submission, approval, posting, reversal, opening-balance, period-open/close, balance, reconciliation, or reporting function has been implemented. Phase 2 payment references still contain no balance, ledger mapping, transaction, or reconciliation state.
