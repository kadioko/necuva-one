# Necuva One Product Requirements

Necuva One is a multi-tenant ERP for Tanzanian SMEs and growing organisations. The platform must support multiple organisations, legal companies, branches, locations, warehouses, currencies and languages.

Phase 0 establishes architecture, local development, tenant security, testing and the application foundation. It deliberately excludes accounting, inventory, sales, purchasing, payroll, and manufacturing business workflows.

## Quality bar

A feature is complete only when its schema, RLS, permissions, validation, business rules, audit events, error handling, tests, user interface, and documentation are complete. Financial and stock logic must be transactional and server-side.

## Initial localisation

The initial locale is Tanzania: TZS, English and Kiswahili, configurable tax and statutory-rate records with effective dates, source references, approval status, and audit history. Necuva One must not claim TRA approval; integrations remain adapters until formal approval.
