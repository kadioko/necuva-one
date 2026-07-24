"use client";
import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { grantSupportAccess, initialPlatformActionState } from "@/features/platform/commands";
export default function GrantSupportPage() { const [state, action, pending] = useActionState(grantSupportAccess, initialPlatformActionState); return <section className="max-w-xl space-y-6"><h1 className="text-2xl font-semibold">Grant support access</h1><form action={action} className="grid gap-3"><Input name="organisationId" placeholder="Organisation ID" required/><Input name="supportUserId" placeholder="Support user ID" required/><Input name="reason" placeholder="Support reason" required/><Input name="expiresAt" required type="datetime-local"/><Button disabled={pending} type="submit">{pending ? "Granting..." : "Grant access"}</Button>{state.message ? <p className="text-sm text-muted-foreground">{state.message}</p> : null}</form></section>; }
