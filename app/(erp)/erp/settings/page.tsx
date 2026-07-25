import { OrganisationStructureForm } from "@/features/platform/components/organisation-structure-form";
import { OrganisationMembershipForm } from "@/features/platform/components/organisation-membership-form";
import { CustomRoleForm } from "@/features/platform/components/custom-role-form";

export default function SettingsPage() {
  return <section className="max-w-3xl space-y-10"><div><p className="text-sm font-medium text-muted-foreground">Organisation settings</p><h1 className="mt-1 text-2xl font-semibold">Administration</h1><p className="mt-2 text-sm leading-6 text-muted-foreground">Manage organisation structure and existing user access within your authorised organisation.</p></div><div className="space-y-4"><h2 className="text-lg font-semibold">Structure management</h2><OrganisationStructureForm /></div><div className="space-y-4 border-t pt-8"><h2 className="text-lg font-semibold">Membership management</h2><OrganisationMembershipForm /></div><div className="space-y-4 border-t pt-8"><h2 className="text-lg font-semibold">Custom roles</h2><CustomRoleForm /></div></section>;
}
