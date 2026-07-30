"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { initialPlatformActionState, manageOrganisationMembership } from "../commands";

export function OrganisationMembershipForm() {
  const [state, action, pending] = useActionState(manageOrganisationMembership, initialPlatformActionState);
  return <form action={action} className="grid gap-4 sm:grid-cols-2">
    <label className="grid gap-2 sm:col-span-2"><Label htmlFor="memberOrganisationId">Organisation ID</Label><Input id="memberOrganisationId" name="organisationId" required /></label>
    <label className="grid gap-2 sm:col-span-2"><Label htmlFor="userId">Existing user ID</Label><Input id="userId" name="userId" required /></label>
    <label className="grid gap-2"><Label htmlFor="roleCode">Role code</Label><Input id="roleCode" list="role-codes" name="roleCode" required/><datalist id="role-codes"><option value="read.only"/><option value="company.admin"/><option value="organisation.owner"/></datalist></label>
    <label className="grid gap-2"><Label htmlFor="status">Status</Label><select className="h-10 rounded-md border bg-background px-3 text-sm" id="status" name="status"><option value="active">Active</option><option value="inactive">Inactive</option></select></label>
    <label className="grid gap-2"><Label htmlFor="scope">Scope</Label><select className="h-10 rounded-md border bg-background px-3 text-sm" id="scope" name="scope"><option value="organisation">Organisation</option><option value="company">Company</option><option value="branch">Branch</option><option value="warehouse">Warehouse</option></select></label>
    <label className="grid gap-2"><Label htmlFor="scopeId">Scope ID</Label><Input id="scopeId" name="scopeId" /></label>
    <div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Updating..." : "Update membership"}</Button></div>
    {state.message ? <p className={state.status === "error" ? "text-sm text-destructive sm:col-span-2" : "text-sm text-muted-foreground sm:col-span-2"}>{state.message}</p> : null}
  </form>;
}
