# Architecture

## Runtime boundaries

The web application uses Next.js App Router, React, TypeScript strict mode, Tailwind and shadcn/ui. Supabase provides PostgreSQL, Auth, Storage and selectively Realtime. Business commands live in server-side feature services, PostgreSQL functions, and controlled RPC endpoints; browser components never own privileged rules.

## Layering

- `app`: route composition, layouts, server actions, route handlers.
- `features`: bounded domain types, schemas, queries, commands, services, components and tests.
- `lib`: cross-cutting auth, permissions, validation, audit, money, dates and errors.
- `supabase`: versioned database infrastructure.

Domain services depend on ports/interfaces where external infrastructure is expected (payments, fiscal devices, storage). This prevents permanent coupling to Vercel or Supabase and permits later managed PostgreSQL, application-server, S3-compatible, or on-premises deployments.

## Trust boundaries

Public clients use only Supabase publishable credentials. Server-side code may use a service role only within narrowly scoped infrastructure adapters; it is never exposed to the browser. Every mutation validates input, resolves the authenticated actor, authorizes on the server/database boundary, executes atomically where needed, and writes an audit event when required.

## Current command model

Implemented mutations use server actions for Zod validation and Supabase RPC for database-side authorisation and atomic writes. Platform commands use platform permissions; tenant commands use organisation permissions and scopes. The service role is used only for the one-time, allow-listed platform-owner bootstrap.

Controlled CSV imports are parsed and size-limited in the server runtime, then staged as tenant-owned database rows. PostgreSQL independently validates references and permissions; only a valid staged batch can invoke existing domain commands inside an atomic confirmation transaction.
