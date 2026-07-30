"use client";
import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { initialPlatformActionState, setTenantContext } from "../commands";
type TenantContextFormProps = { branchId?: string | null; companyId?: string | null; organisationId?: string | null; warehouseId?: string | null };
export function TenantContextForm({ branchId, companyId, organisationId, warehouseId }: TenantContextFormProps) { const [state, action, pending] = useActionState(setTenantContext, initialPlatformActionState); return <form action={action} className="grid max-w-2xl gap-3 sm:grid-cols-2"><Input className="sm:col-span-2" defaultValue={organisationId ?? ""} name="organisationId" placeholder="Organisation ID" required/><Input defaultValue={companyId ?? ""} name="companyId" placeholder="Company ID (optional)"/><Input defaultValue={branchId ?? ""} name="branchId" placeholder="Branch ID (optional)"/><Input className="sm:col-span-2" defaultValue={warehouseId ?? ""} name="warehouseId" placeholder="Warehouse ID (optional)"/><div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Saving..." : "Save workspace context"}</Button></div>{state.message ? <p className="text-sm text-muted-foreground sm:col-span-2">{state.message}</p> : null}</form>; }
