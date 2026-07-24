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
    <label className="grid gap-2"><Label htmlFor="roleCode">Role</Label><select className="h-10 rounded-md border bg-background px-3 text-sm" id="roleCode" name="roleCode"><option value="read.only">Read-only user</option><option value="company.admin">Company administrator</option><option value="organisation.owner">Organisation owner</option></select></label>
    <label className="grid gap-2"><Label htmlFor="status">Status</Label><select className="h-10 rounded-md border bg-background px-3 text-sm" id="status" name="status"><option value="active">Active</option><option value="inactive">Inactive</option></select></label>
    <div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Updating..." : "Update membership"}</Button></div>
    {state.message ? <p className={state.status === "error" ? "text-sm text-destructive sm:col-span-2" : "text-sm text-muted-foreground sm:col-span-2"}>{state.message}</p> : null}
  </form>;
}
