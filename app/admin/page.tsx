import { connection } from "next/server";

import { PlatformProvisioning } from "@/features/platform/components/platform-provisioning";
import { TenantLifecycleForm } from "@/features/platform/components/tenant-lifecycle-form";
import { SubscriptionPlanForm } from "@/features/platform/components/subscription-plan-form";
import { SubscriptionAssignmentForm } from "@/features/platform/components/subscription-assignment-form";
import { ImplementationStageForm } from "@/features/platform/components/implementation-stage-form";
import { CurrencyForm } from "@/features/master-data/components/currency-form";
import { requireUser } from "@/lib/auth/require-user";

export default async function ControlCentrePage() {
  await connection();
  await requireUser();

  return (
    <main className="mx-auto max-w-5xl space-y-8 p-5 md:p-8">
      <div className="space-y-3">
        <p className="text-sm font-medium text-muted-foreground">Necuva Control Centre</p>
        <h1 className="text-2xl font-semibold tracking-normal">Platform administration</h1>
        <p className="max-w-2xl text-sm leading-6 text-muted-foreground">
          Tenant business data is never displayed here by default. Provisioning permissions are enforced in PostgreSQL.
        </p>
      </div>
      <PlatformProvisioning />
      <section className="space-y-4 border-t pt-8"><div><h2 className="text-lg font-semibold">Tenant lifecycle</h2><p className="mt-1 text-sm text-muted-foreground">Change a customer organisation status with a reasoned audit event.</p></div><TenantLifecycleForm /></section>
      <section className="space-y-4 border-t pt-8"><div><h2 className="text-lg font-semibold">Subscription plans</h2><p className="mt-1 text-sm text-muted-foreground">Create or update commercial plan pricing in the platform database.</p></div><SubscriptionPlanForm /></section>
      <section className="space-y-4 border-t pt-8"><div><h2 className="text-lg font-semibold">Currencies</h2><p className="mt-1 text-sm text-muted-foreground">Maintain the shared currency reference data used by tenant localisation settings.</p></div><CurrencyForm /></section>
      <section className="space-y-4 border-t pt-8"><div><h2 className="text-lg font-semibold">Tenant subscriptions</h2><p className="mt-1 text-sm text-muted-foreground">Assign an active subscription plan to a customer organisation.</p></div><SubscriptionAssignmentForm /></section>
      <section className="space-y-4 border-t pt-8"><div><h2 className="text-lg font-semibold">Client implementation</h2><p className="mt-1 text-sm text-muted-foreground">Record the current customer onboarding stage.</p></div><ImplementationStageForm /></section>
    </main>
  );
}
