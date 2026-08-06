"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { initialMasterDataActionState, upsertCurrency } from "../commands";

export function CurrencyForm() {
  const [state, action, pending] = useActionState(upsertCurrency, initialMasterDataActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><label className="grid gap-2"><Label htmlFor="currencyCode">ISO code</Label><Input id="currencyCode" maxLength={3} name="code" required /></label><label className="grid gap-2"><Label htmlFor="currencyName">Name</Label><Input id="currencyName" name="name" required /></label><label className="grid gap-2"><Label htmlFor="currencySymbol">Symbol</Label><Input id="currencySymbol" name="symbol" required /></label><label className="grid gap-2"><Label htmlFor="currencyDecimals">Decimal places</Label><Input defaultValue="2" id="currencyDecimals" max="4" min="0" name="decimalPlaces" required type="number" /></label><label className="grid gap-2"><Label htmlFor="currencyActive">Status</Label><select className="h-10 rounded-md border bg-background px-3 text-sm" id="currencyActive" name="isActive"><option value="true">Active</option><option value="false">Inactive</option></select></label><div className="self-end"><Button disabled={pending} type="submit">{pending ? "Saving..." : "Save currency"}</Button></div>{state.message ? <p className={state.status === "error" ? "text-sm text-destructive sm:col-span-2" : "text-sm text-muted-foreground sm:col-span-2"}>{state.message}</p> : null}</form>;
}
