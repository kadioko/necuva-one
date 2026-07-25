# Testing Strategy

Vitest tests pure services and integration boundaries. React Testing Library tests interactive components. Playwright covers authenticated critical workflows. Supabase/PostgreSQL tests verify RLS and future transactional functions.

Required Phase 0 coverage includes tenant A isolation from tenant B, branch-scope isolation, absence of implicit support access, validation failures, and authenticated shell routing. Tests use deterministic seeds and must not rely on production data.

Phase 1 adds database tests that prove an authorised platform owner can provision a tenant, provisioning creates the owner membership, and an unauthorised user is rejected. These run through `npm run test:db` after `supabase start`.

Current automated coverage includes schema validation for provisioning, scoped memberships, lifecycle updates, and plan inputs. Database tests remain required for every new security-definer RPC; local execution is blocked until Docker Desktop's Linux daemon is available.
