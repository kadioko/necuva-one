"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { grantSupportAccess, initialPlatformActionState } from "@/features/platform/commands";

export default function SupportPage() {
  const [state, action, pending] = useActionState(grantSupportAccess, initialPlatformActionState);
  return <section className="max-w-2xl space-y-6"><div><p className="text-sm font-medium text-muted-foreground">Organisation settings</p><h1 className="mt-1 text-2xl font-semibold">Support access</h1><p className="mt-2 text-sm leading-6 text-muted-foreground">Grant a Necuva staff member temporary, auditable access for a specific support reason.</p></div><form action={action} className="grid gap-4"><label className="grid gap-2"><Label htmlFor="organisationId">Organisation ID</Label><Input id="organisationId" name="organisationId" required /></label><label className="grid gap-2"><Label htmlFor="supportUserId">Support user ID</Label><Input id="supportUserId" name="supportUserId" required /></label><label className="grid gap-2"><Label htmlFor="reason">Reason</Label><Input id="reason" name="reason" required /></label><label className="grid gap-2"><Label htmlFor="expiresAt">Expires at</Label><Input id="expiresAt" name="expiresAt" required type="datetime-local" /></label><Button disabled={pending} type="submit">{pending ? "Granting..." : "Grant support access"}</Button>{state.message ? <p className={state.status === "error" ? "text-sm text-destructive" : "text-sm text-muted-foreground"}>{state.message}</p> : null}</form></section>;
}
