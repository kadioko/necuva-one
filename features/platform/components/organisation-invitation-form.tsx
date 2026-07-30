"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { initialPlatformActionState, inviteOrganisationMember } from "../commands";

export function OrganisationInvitationForm() {
  const [state, action, pending] = useActionState(inviteOrganisationMember, initialPlatformActionState);

  return <form action={action} className="grid gap-4 sm:grid-cols-2">
    <label className="grid gap-2 sm:col-span-2"><Label htmlFor="inviteOrganisationId">Organisation ID</Label><Input id="inviteOrganisationId" name="organisationId" required /></label>
    <label className="grid gap-2 sm:col-span-2"><Label htmlFor="inviteEmail">Email address</Label><Input id="inviteEmail" name="email" type="email" required /></label>
    <label className="grid gap-2"><Label htmlFor="inviteRoleCode">Role code</Label><Input id="inviteRoleCode" list="invite-role-codes" name="roleCode" required /><datalist id="invite-role-codes"><option value="read.only" /><option value="company.admin" /><option value="organisation.owner" /></datalist></label>
    <label className="grid gap-2"><Label htmlFor="inviteScope">Scope</Label><select className="h-10 rounded-md border bg-background px-3 text-sm" id="inviteScope" name="scope"><option value="organisation">Organisation</option><option value="company">Company</option><option value="branch">Branch</option><option value="warehouse">Warehouse</option></select></label>
    <label className="grid gap-2 sm:col-span-2"><Label htmlFor="inviteScopeId">Scope ID</Label><Input id="inviteScopeId" name="scopeId" /></label>
    <div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Sending..." : "Send invitation"}</Button></div>
    {state.message ? <p className={state.status === "error" ? "text-sm text-destructive sm:col-span-2" : "text-sm text-muted-foreground sm:col-span-2"}>{state.message}</p> : null}
  </form>;
}
