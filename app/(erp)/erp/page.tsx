import { Building2, GitBranch, Warehouse } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { TenantContextForm } from "@/features/platform/components/tenant-context-form";
import { createClient } from "@/lib/supabase/server";

type TenantDashboard = {
  branchCount: number;
  branchId: string | null;
  companyCount: number;
  companyId: string | null;
  implementationStage: string | null;
  organisationId: string;
  organisationName: string;
  organisationStatus: string;
  subscriptionCode: string | null;
  subscriptionPlan: string | null;
  warehouseCount: number;
  warehouseId: string | null;
};

const metrics = [
  { icon: Building2, key: "companyCount", label: "Companies" },
  { icon: GitBranch, key: "branchCount", label: "Branches" },
  { icon: Warehouse, key: "warehouseCount", label: "Warehouses" },
] as const;

export default async function ErpOverviewPage() {
  const supabase = await createClient();
  const { data } = await supabase.rpc("get_tenant_dashboard");
  const dashboard = data as TenantDashboard | null;

  if (!dashboard) return <section className="space-y-6"><div><p className="text-sm font-medium text-muted-foreground">Workspace</p><h1 className="mt-1 text-2xl font-semibold">Organisation overview</h1><p className="mt-2 max-w-2xl text-sm leading-6 text-muted-foreground">Choose an authorised organisation and optional location to load your workspace.</p></div><TenantContextForm /></section>;

  return <section className="space-y-8"><div className="flex flex-wrap items-start justify-between gap-3"><div><p className="text-sm font-medium text-muted-foreground">Workspace</p><h1 className="mt-1 text-2xl font-semibold">{dashboard.organisationName}</h1><p className="mt-2 text-sm text-muted-foreground">{dashboard.subscriptionPlan ?? "No subscription assigned"} {dashboard.subscriptionCode ? `(${dashboard.subscriptionCode})` : ""}</p></div><Badge variant={dashboard.organisationStatus === "active" ? "default" : "secondary"}>{dashboard.organisationStatus}</Badge></div><div className="grid gap-3 sm:grid-cols-3">{metrics.map(({ icon: Icon, key, label }) => <div className="border bg-card p-4" key={key}><Icon aria-hidden="true" className="mb-4 size-4 text-muted-foreground"/><p className="text-2xl font-semibold">{dashboard[key]}</p><p className="mt-1 text-sm text-muted-foreground">{label} in this context</p></div>)}</div><div className="grid gap-6 border-t pt-6 lg:grid-cols-2"><div><h2 className="text-lg font-semibold">Implementation</h2><p className="mt-2 text-sm text-muted-foreground">Current stage: <span className="font-medium text-foreground">{dashboard.implementationStage?.replaceAll("_", " ") ?? "Not recorded"}</span></p></div><div><h2 className="text-lg font-semibold">Change workspace</h2><p className="mt-2 text-sm text-muted-foreground">Your selection is saved to this account and is checked against your current scope.</p></div></div><TenantContextForm branchId={dashboard.branchId} companyId={dashboard.companyId} organisationId={dashboard.organisationId} warehouseId={dashboard.warehouseId} /></section>;
}
