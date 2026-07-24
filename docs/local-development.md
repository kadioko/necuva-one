# Local Development

## Prerequisites

Use Node.js 22 or 24, npm 11+, Docker Desktop with the Linux engine running, and Supabase CLI 2.109 or later. Run commands from the repository root.

## Start the stack

1. Run `npm ci`.
2. Copy `.env.example` to `.env.local`.
3. Run `supabase start`.
4. Copy the local API URL and publishable key into `.env.local`.
5. Run `supabase db reset` to recreate the database from committed migrations and seed data.
6. Run `npm run dev`.

Use `supabase status` to retrieve local connection details and `supabase stop` when finished. Never paste a service-role key into a `NEXT_PUBLIC_` variable.

## Quality commands

| Command | Purpose |
| --- | --- |
| `npm run lint` | ESLint checks |
| `npm run typecheck` | TypeScript strict-mode checks |
| `npm run test` | Vitest unit/component checks |
| `npm run test:db` | pgTAP RLS and database-function checks |
| `npm run build` | Production build validation |
| `npm run check` | Lint, typecheck, and unit tests |

## Bootstrap flow

Create the first account through Supabase Auth, set its exact email in `NECUVA_BOOTSTRAP_EMAILS`, sign in, and use the Control Centre once. Remove the bootstrap allow-list entry after the owner is established unless a controlled recovery process requires it.

## Troubleshooting

`supabase start`, `supabase db reset`, and `npm run test:db` require Docker Desktop's Linux daemon. If the CLI cannot connect, start Docker Desktop, wait for the Linux engine to report healthy, then run `docker version` before retrying. Do not hand-edit a database to bypass a failing migration; fix the migration and reset the local database.
