# Testing Strategy

Vitest tests pure services and integration boundaries. React Testing Library tests interactive components. Playwright covers authenticated critical workflows. Supabase/PostgreSQL tests verify RLS and future transactional functions.

Required Phase 0 coverage includes tenant A isolation from tenant B, branch-scope isolation, absence of implicit support access, validation failures, and authenticated shell routing. Tests use deterministic seeds and must not rely on production data.

Phase 1 adds database tests that prove an authorised platform owner can provision a tenant, provisioning creates the owner membership, and an unauthorised user is rejected. These run through `npm run test:db` after `supabase start`.

Current automated coverage includes schema validation for provisioning, scoped memberships, invitations, lifecycle updates, plan inputs, currencies, exchange rates, tax configurations, business parties, the item catalogue, payment references, strict CSV parsing, and accounting configuration. pgTAP verifies localisation, business-party, catalogue, company-scoped payment-reference/accounting, and controlled-import permission boundaries. Accounting database coverage checks generated normal balances, group/account type consistency, twelve-period generation, fiscal overlap rejection, and company isolation. Database tests remain required for every new security-definer RPC; local execution is blocked until Docker Desktop's Linux daemon is available.

Playwright covers anonymous protected-route redirects, sign-up validation, and authenticated protected-page access. CI starts Supabase, exports its local browser credentials, and runs the browser suite after database tests.
