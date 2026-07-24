# Security Checklist

- [ ] RLS enabled and tested on every tenant-owned table.
- [ ] Server-side authorization and Zod validation on mutations.
- [ ] Service-role access isolated from browser code and logs.
- [ ] Security headers, secure sessions and rate limiting configured.
- [ ] Upload type/size checks and signed URLs used for documents.
- [ ] Secrets validated at startup and excluded from source control.
- [ ] Audit events are append-only to normal users.
- [ ] Support access is explicit, expiring, revocable and auditable.
- [ ] Error messages do not reveal sensitive business data.
- [ ] Production readiness review completed before customer go-live.
