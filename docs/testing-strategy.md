# Testing Strategy

Vitest tests pure services and integration boundaries. React Testing Library tests interactive components. Playwright covers authenticated critical workflows. Supabase/PostgreSQL tests verify RLS and future transactional functions.

Required Phase 0 coverage includes tenant A isolation from tenant B, branch-scope isolation, absence of implicit support access, validation failures, and authenticated shell routing. Tests use deterministic seeds and must not rely on production data.
