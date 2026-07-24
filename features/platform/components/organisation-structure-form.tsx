"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { addOrganisationStructure, initialPlatformActionState } from "../commands";

export function OrganisationStructureForm() {
  const [state, action, pending] = useActionState(addOrganisationStructure, initialPlatformActionState);
  return <form action={action} className="grid gap-4 sm:grid-cols-2">
    <label className="grid gap-2 sm:col-span-2"><Label htmlFor="organisationId">Organisation ID</Label><Input id="organisationId" name="organisationId" required /></label>
    <label className="grid gap-2"><Label htmlFor="entityType">Record type</Label><select className="h-10 rounded-md border bg-background px-3 text-sm" id="entityType" name="entityType"><option value="company">Company</option><option value="branch">Branch</option><option value="department">Department</option><option value="warehouse">Warehouse</option></select></label>
    <label className="grid gap-2"><Label htmlFor="name">Name</Label><Input id="name" name="name" required /></label>
    <label className="grid gap-2"><Label htmlFor="code">Code</Label><Input id="code" name="code" /></label>
    <label className="grid gap-2"><Label htmlFor="companyId">Company ID</Label><Input id="companyId" name="companyId" /></label>
    <label className="grid gap-2 sm:col-span-2"><Label htmlFor="branchId">Branch ID</Label><Input id="branchId" name="branchId" /></label>
    <div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Creating..." : "Add structure record"}</Button></div>
    {state.message ? <p className={state.status === "error" ? "text-sm text-destructive sm:col-span-2" : "text-sm text-muted-foreground sm:col-span-2"}>{state.message}</p> : null}
  </form>;
}
