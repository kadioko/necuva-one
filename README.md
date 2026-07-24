# Necuva One

Necuva One is a security-first, multi-tenant ERP platform for Necuva Group Limited. The repository contains the Phase 0 foundation and the first Phase 1 platform-core slice: secure platform-owner bootstrap and atomic customer-organisation provisioning.

## Requirements

- Node.js 22 or 24
- npm 11+
- Docker Desktop (running) for local Supabase
- Supabase CLI 2.109+

## Local setup

1. Install dependencies with `npm ci`.
2. Copy `.env.example` to `.env.local`.
3. Run `supabase start` and copy the local API URL and publishable key shown by the CLI into `.env.local`.
4. Run `supabase db reset` to apply migrations and deterministic seed data.
5. Run `npm run dev` and open `http://localhost:3000`.

Run `npm run check`, `npm run test:db`, and `npm run build` before opening a pull request. Database checks require Docker Desktop's Linux engine.

## Environment variables

| Variable | Purpose | Exposure |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase API endpoint | Browser-safe |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Supabase publishable key | Browser-safe |
| `NEXT_PUBLIC_APP_URL` | Application origin | Browser-safe |
| `SUPABASE_SERVICE_ROLE_KEY` | Infrastructure-only privileged operations | Server-only; do not add `NEXT_PUBLIC_` |
| `NECUVA_BOOTSTRAP_EMAILS` | Comma-separated allow-list for the initial platform owner | Server-only |

The app validates required public Supabase values when it creates a Supabase client. Never commit `.env.local` or production credentials.

The first platform owner must first sign up through Supabase Auth. Set that exact email address in `NECUVA_BOOTSTRAP_EMAILS`, sign in, and use the Control Centre bootstrap action once. Thereafter, platform owners provision organisations through the same Control Centre; PostgreSQL checks `platform.organisations.provision` before making any tenant records.

## Supabase and Vercel

Create separate Supabase projects for development, preview/staging, and production. Apply committed migrations through CI or controlled `supabase db push` commands; do not use dashboard changes as the source of truth. Set the exact Vercel preview and production URLs in Supabase Auth redirect settings.

For Vercel, import `kadioko/necuva-one`, configure the public Supabase values for each environment, and keep service-role credentials out of preview environments unless a server-only integration explicitly needs them. Vercel creates preview deployments for pull requests once GitHub integration is enabled.

## Current scope

No accounting, sales, inventory, purchasing, payroll, manufacturing, posting engine, or operational master data is implemented. The next Platform Core work is company, branch, department, warehouse, membership, and scoped-role management.

Start with the [documentation index](docs/README.md), then review the [Phase 1 status](docs/phase-1-platform-core.md), [local development guide](docs/local-development.md), [module roadmap](docs/module-roadmap.md), and [security checklist](docs/security-checklist.md).
