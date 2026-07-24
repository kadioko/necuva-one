# Deployment Strategy

Development uses Vercel previews and Supabase Free. Each pull request runs linting, type checking, unit tests and build validation. Secrets are configured in Vercel and GitHub, never committed.

Before commercial production, upgrade Vercel and Supabase plans; enable backups and point-in-time recovery; add monitoring, error tracking, rate limiting, custom domains, disaster recovery exercises, data-processing agreements, penetration/load testing, support procedures, payment integrations and formally approved fiscal integrations.
