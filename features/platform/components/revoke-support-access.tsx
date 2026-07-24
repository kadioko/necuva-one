"use client";
import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { revokeSupportAccess, initialPlatformActionState } from "../commands";
export function RevokeSupportAccess({ grantId }: { grantId: string }) { const [state, action, pending] = useActionState(revokeSupportAccess, initialPlatformActionState); return <form action={action} className="flex gap-2"><input name="grantId" type="hidden" value={grantId}/><input className="h-8 min-w-0 rounded border px-2 text-xs" name="reason" placeholder="Reason"/><Button disabled={pending} size="sm" type="submit">Revoke</Button>{state.status === "error" ? <span className="text-xs text-destructive">Failed</span> : null}</form>; }
