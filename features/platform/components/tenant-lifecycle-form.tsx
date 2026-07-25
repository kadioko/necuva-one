"use client";
import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { initialPlatformActionState, setOrganisationStatus } from "../commands";
export function TenantLifecycleForm() { const [state, action, pending] = useActionState(setOrganisationStatus, initialPlatformActionState); return <form action={action} className="grid gap-3 sm:grid-cols-2"><Input name="organisationId" placeholder="Organisation ID" required/><select className="h-10 rounded-md border bg-background px-3 text-sm" name="status"><option value="active">Active</option><option value="grace_period">Grace period</option><option value="suspended">Suspended</option><option value="closed">Closed</option></select><Input className="sm:col-span-2" name="reason" placeholder="Reason" required/><div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Updating..." : "Update tenant status"}</Button></div>{state.message ? <p className="text-sm text-muted-foreground sm:col-span-2">{state.message}</p> : null}</form>; }
