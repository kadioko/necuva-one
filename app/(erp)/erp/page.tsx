import { TenantContextForm } from "@/features/platform/components/tenant-context-form";

export default function ErpOverviewPage() {
  return (
    <section className="space-y-6">
      <p className="text-sm font-medium text-muted-foreground">Workspace</p>
      <h1 className="text-2xl font-semibold tracking-normal">Organisation overview</h1>
      <p className="max-w-2xl text-sm leading-6 text-muted-foreground">
        Select an organisation to begin. Financial and operational dashboards will appear after their respective modules are implemented.
      </p>
      <TenantContextForm />
    </section>
  );
}
