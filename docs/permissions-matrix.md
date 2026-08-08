# Permissions Matrix

Permissions are named actions rather than UI roles. Roles bundle permissions; a member can hold several roles and scopes.

| Role | Initial scope | Core permissions |
| --- | --- | --- |
| Platform Owner | Platform | platform administration |
| Platform Administrator | Platform | customer provisioning, subscriptions |
| Support Officer | None by default | access only through a grant |
| Organisation Owner | Organisation | tenant administration |
| Company Administrator | Company | company configuration and users |
| Finance Manager | Company | future finance approvals |
| Accountant | Company | future finance preparation |
| Cashier | Branch | future cash operations |
| Sales Manager | Company | future sales management |
| Sales Representative | Own records/Branch | future sales operations |
| Procurement Manager | Company | future procurement approvals |
| Procurement Officer | Branch | future procurement preparation |
| Warehouse Manager | Warehouse | future warehouse administration |
| Storekeeper | Warehouse | future stock operations |
| HR Manager | Company | future HR administration |
| Payroll Officer | Company | future payroll preparation |
| Project Manager | Company | future project operations |
| Auditor | Organisation | read and audit access |
| Read-Only User | Assigned scope | read-only permissions |

Phase 0 seeds only platform and organisation-administration permissions. Financial permissions are reserved until their command handlers exist.

Phase 1 implements `platform.organisations.provision`. The initial platform owner is created once through a service-role RPC, but only after the server action verifies the authenticated email against `NECUVA_BOOTSTRAP_EMAILS`. The allow-list is server-only and is never sent to the browser.

Organisation owners now receive `organisation.structure.manage`, allowing them to create companies, branches, departments, and warehouses only within their own organisation.

Organisation owners also receive `organisation.memberships.manage`. The current screen manages existing authenticated users; invitation delivery and granular scopes remain a later Phase 1 slice.

Organisation owners receive `organisation.audit.read` and can search the most recent authorised audit events from the ERP audit trail.

Organisation owners also manage support access, custom roles, Phase 2 localisation configuration, business-party master data, the item catalogue, payment references, and controlled imports. Tenant localisation separates draft creation (`organisation.localisation.manage`) from approval (`organisation.localisation.approve`); both are initially granted to organisation owners. Party categories, parties, contacts, and addresses require `organisation.parties.manage`; catalogue categories, units, conversions, items, and barcodes require `organisation.catalog.manage`; company payment methods and settlement accounts require the scope-aware `organisation.payment_references.manage`. Import staging and confirmation require `organisation.imports.manage` plus the permission for the target domain, preventing import access from bypassing ordinary mutation rules. Platform owners maintain shared currency data through `platform.localisation.manage`. Custom roles are tenant-owned and limited to currently supported organisation permissions; custom roles cannot receive platform privileges.
