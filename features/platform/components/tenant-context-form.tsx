"use client";
import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { initialPlatformActionState, setTenantContext } from "../commands";
export function TenantContextForm() { const [state, action, pending] = useActionState(setTenantContext, initialPlatformActionState); return <form action={action} className="grid max-w-2xl gap-3 sm:grid-cols-2"><Input className="sm:col-span-2" name="organisationId" placeholder="Organisation ID" required/><Input name="companyId" placeholder="Company ID (optional)"/><Input name="branchId" placeholder="Branch ID (optional)"/><Input className="sm:col-span-2" name="warehouseId" placeholder="Warehouse ID (optional)"/><div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Saving..." : "Save workspace context"}</Button></div>{state.message ? <p className="text-sm text-muted-foreground sm:col-span-2">{state.message}</p> : null}</form>; }
