# Necuva One

Necuva One is a security-first, multi-tenant ERP platform for Necuva Group Limited. This repository currently contains Phase 0: architecture documentation, the tenant-security database baseline, local Supabase configuration, authenticated application shells, and quality gates.

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

Run the quality gates with `npm run check`, and run production validation with `npm run build`.

## Environment variables

| Variable | Purpose | Exposure |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase API endpoint | Browser-safe |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Supabase publishable key | Browser-safe |
| `NEXT_PUBLIC_APP_URL` | Application origin | Browser-safe |
| `SUPABASE_SERVICE_ROLE_KEY` | Infrastructure-only privileged operations | Server-only; do not add `NEXT_PUBLIC_` |

The app validates required public Supabase values when it creates a Supabase client. Never commit `.env.local` or production credentials.

## Supabase and Vercel

Create separate Supabase projects for development, preview/staging, and production. Apply committed migrations through CI or controlled `supabase db push` commands; do not use dashboard changes as the source of truth. Set the exact Vercel preview and production URLs in Supabase Auth redirect settings.

For Vercel, import `kadioko/necuva-one`, configure the public Supabase values for each environment, and keep service-role credentials out of preview environments unless a server-only integration explicitly needs them. Vercel creates preview deployments for pull requests once GitHub integration is enabled.

## Current scope

No accounting, sales, inventory, purchasing, payroll, manufacturing, posting engine, or operational master data is implemented. See [`docs/module-roadmap.md`](docs/module-roadmap.md) for the staged roadmap and [`docs/security-checklist.md`](docs/security-checklist.md) for the security review list.
