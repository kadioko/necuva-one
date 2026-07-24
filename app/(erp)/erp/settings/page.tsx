import { OrganisationStructureForm } from "@/features/platform/components/organisation-structure-form";

export default function SettingsPage() {
  return <section className="max-w-3xl space-y-6"><div><p className="text-sm font-medium text-muted-foreground">Organisation settings</p><h1 className="mt-1 text-2xl font-semibold">Structure management</h1><p className="mt-2 text-sm leading-6 text-muted-foreground">Create companies, branches, departments, and warehouses within your authorised organisation.</p></div><OrganisationStructureForm /></section>;
}
