# Security Checklist

- [x] RLS enabled on every current tenant-owned table; database tests are configured in CI and require confirmation of their first successful run.
- [x] Server-side authorization and Zod validation on implemented mutations.
- [x] Service-role access isolated in a server-only module and excluded from browser code.
- [x] Security headers and secure cookie-backed sessions are configured; endpoint rate limiting remains pending.
- [ ] Upload type/size checks and signed URLs used for documents.
- [x] Required public and server-only environment variables are validated where clients are created; secrets are excluded from source control.
- [x] Audit events are append-only to normal users and written by provisioning RPCs.
- [x] Payment account identifiers require scope-aware permission checks and are masked in interfaces and audit payloads.
- [x] Support access is explicit, expires within seven days, is revocable, and is audited.
- [ ] Error messages do not reveal sensitive business data.
- [ ] Production readiness review completed before customer go-live.
