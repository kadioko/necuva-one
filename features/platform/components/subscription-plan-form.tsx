"use client";
import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { initialPlatformActionState, upsertSubscriptionPlan } from "../commands";
export function SubscriptionPlanForm() { const [state, action, pending] = useActionState(upsertSubscriptionPlan, initialPlatformActionState); return <form action={action} className="grid gap-3 sm:grid-cols-2"><Input name="code" placeholder="Plan code, e.g. growth" required/><Input name="name" placeholder="Plan name" required/><Input name="monthlyPriceMinor" placeholder="Monthly price in minor units" required/><select className="h-10 rounded-md border bg-background px-3 text-sm" name="isActive"><option value="true">Active</option><option value="false">Inactive</option></select><div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Saving..." : "Save subscription plan"}</Button></div>{state.message ? <p className="text-sm text-muted-foreground sm:col-span-2">{state.message}</p> : null}</form>; }
