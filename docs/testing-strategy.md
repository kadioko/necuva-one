# Testing Strategy

Vitest tests pure services and integration boundaries. React Testing Library tests interactive components. Playwright covers authenticated critical workflows. Supabase/PostgreSQL tests verify RLS and future transactional functions.

Required Phase 0 coverage includes tenant A isolation from tenant B, branch-scope isolation, absence of implicit support access, validation failures, and authenticated shell routing. Tests use deterministic seeds and must not rely on production data.

Phase 1 adds database tests that prove an authorised platform owner can provision a tenant, provisioning creates the owner membership, and an unauthorised user is rejected. These run through `npm run test:db` after `supabase start`.

Current automated coverage includes schema validation for provisioning, scoped memberships, invitations, lifecycle updates, plan inputs, currencies, exchange rates, tax configurations, business parties, the item catalogue, payment references, strict CSV parsing, accounting configuration, exact decimal-to-minor-unit conversion, and draft-journal balance normalization. pgTAP verifies localisation, business-party, catalogue, company-scoped payment-reference/accounting, controlled-import, and branch-scoped journal permission boundaries. Journal database coverage checks atomic numbering and line creation, base-currency derivation, draft-only state, balance rejection, control-account rejection, fiscal-date rejection, direct-write denial, branch isolation, outsider denial, and audit creation. Database tests remain required for every new security-definer RPC; local execution is blocked until Docker Desktop's Linux daemon is available.

Playwright covers anonymous protected-route redirects, sign-up validation, and authenticated protected-page access. CI starts Supabase, exports its local browser credentials, and runs the browser suite after database tests.
