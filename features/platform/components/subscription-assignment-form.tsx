"use client";
import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { assignSubscriptionPlan, initialPlatformActionState } from "../commands";
export function SubscriptionAssignmentForm() { const [state, action, pending] = useActionState(assignSubscriptionPlan, initialPlatformActionState); return <form action={action} className="flex max-w-xl flex-wrap gap-3"><Input className="flex-1" name="organisationId" placeholder="Organisation ID" required/><Input className="flex-1" name="planCode" placeholder="Plan code" required/><Button disabled={pending} type="submit">{pending ? "Assigning..." : "Assign plan"}</Button>{state.message ? <p className="w-full text-sm text-muted-foreground">{state.message}</p> : null}</form>; }
