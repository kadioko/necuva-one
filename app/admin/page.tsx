import { connection } from "next/server";

import { requireUser } from "@/lib/auth/require-user";

export default async function ControlCentrePage() {
  await connection();
  await requireUser();

  return (
    <main className="mx-auto max-w-5xl space-y-3 p-5 md:p-8">
      <p className="text-sm font-medium text-muted-foreground">Necuva Control Centre</p>
      <h1 className="text-2xl font-semibold tracking-normal">Platform administration</h1>
      <p className="max-w-2xl text-sm leading-6 text-muted-foreground">
        Platform administration will be available only to authorised Necuva staff. Tenant business data is not displayed here by default.
      </p>
    </main>
  );
}
