import { connection } from "next/server";

import { requireUser } from "@/lib/auth/require-user";

export default async function OnboardingPage() {
  await connection();
  await requireUser();

  return (
    <main className="mx-auto max-w-5xl space-y-3 p-5 md:p-8">
      <p className="text-sm font-medium text-muted-foreground">Implementation</p>
      <h1 className="text-2xl font-semibold tracking-normal">Client onboarding</h1>
      <p className="max-w-2xl text-sm leading-6 text-muted-foreground">
        Implementation records and data-import workflows will be introduced in the Platform Core and Master Data phases.
      </p>
    </main>
  );
}
