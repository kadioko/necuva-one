# Security Checklist

- [x] RLS enabled on every current tenant-owned table; database tests run in CI.
- [x] Server-side authorization and Zod validation on implemented mutations.
- [x] Service-role access isolated in a server-only module and excluded from browser code.
- [ ] Security headers, secure sessions and rate limiting configured.
- [ ] Upload type/size checks and signed URLs used for documents.
- [ ] Secrets validated at startup and excluded from source control.
- [x] Audit events are append-only to normal users and written by provisioning RPCs.
- [ ] Support access is explicit, expiring, revocable and auditable.
- [ ] Error messages do not reveal sensitive business data.
- [ ] Production readiness review completed before customer go-live.
