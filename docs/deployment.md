# Deployment Strategy

Development uses Vercel previews and Supabase Free. Each pull request runs linting, type checking, unit tests and build validation. Secrets are configured in Vercel and GitHub, never committed.

The CI workflow also starts local Supabase and runs pgTAP database tests. Configure Vercel preview and production URLs in Supabase Auth's redirect allow-list, and configure each environment with its own Supabase URL and publishable key. `SUPABASE_SERVICE_ROLE_KEY` and `NECUVA_BOOTSTRAP_EMAILS` remain server-only Vercel secrets.

Before commercial production, upgrade Vercel and Supabase plans; enable backups and point-in-time recovery; add monitoring, error tracking, rate limiting, custom domains, disaster recovery exercises, data-processing agreements, penetration/load testing, support procedures, payment integrations and formally approved fiscal integrations.
