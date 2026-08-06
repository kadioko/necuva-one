"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { createExchangeRateVersion, createTaxConfigurationVersion, initialMasterDataActionState } from "../commands";

export function ExchangeRateForm({ organisationId }: { organisationId: string }) {
  const [state, action, pending] = useActionState(createExchangeRateVersion, initialMasterDataActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><label className="grid gap-2"><Label htmlFor="exchangeCurrency">Currency code</Label><Input id="exchangeCurrency" maxLength={3} name="currencyCode" required /></label><label className="grid gap-2"><Label htmlFor="exchangeDate">Effective on</Label><Input id="exchangeDate" name="effectiveOn" required type="date" /></label><label className="grid gap-2"><Label htmlFor="exchangeRate">Rate</Label><Input id="exchangeRate" inputMode="decimal" name="rate" required /></label><label className="grid gap-2"><Label htmlFor="exchangeSource">Source reference</Label><Input id="exchangeSource" name="sourceReference" required /></label><div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Creating..." : "Create exchange-rate draft"}</Button></div>{state.message ? <p className={state.status === "error" ? "text-sm text-destructive sm:col-span-2" : "text-sm text-muted-foreground sm:col-span-2"}>{state.message}</p> : null}</form>;
}

export function TaxConfigurationForm({ organisationId }: { organisationId: string }) {
  const [state, action, pending] = useActionState(createTaxConfigurationVersion, initialMasterDataActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><label className="grid gap-2"><Label htmlFor="taxCode">Tax code</Label><Input id="taxCode" name="code" required /></label><label className="grid gap-2"><Label htmlFor="taxName">Name</Label><Input id="taxName" name="name" required /></label><label className="grid gap-2"><Label htmlFor="taxType">Type</Label><select className="h-10 rounded-md border bg-background px-3 text-sm" id="taxType" name="taxType"><option value="vat">VAT</option><option value="withholding">Withholding</option><option value="other">Other</option></select></label><label className="grid gap-2"><Label htmlFor="taxRate">Rate percent</Label><Input id="taxRate" inputMode="decimal" name="ratePercent" required /></label><label className="grid gap-2"><Label htmlFor="taxStart">Effective from</Label><Input id="taxStart" name="effectiveFrom" required type="date" /></label><label className="grid gap-2"><Label htmlFor="taxEnd">Effective to</Label><Input id="taxEnd" name="effectiveTo" type="date" /></label><label className="grid gap-2 sm:col-span-2"><Label htmlFor="taxSource">Source reference</Label><Input id="taxSource" name="sourceReference" required /></label><div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Creating..." : "Create tax draft"}</Button></div>{state.message ? <p className={state.status === "error" ? "text-sm text-destructive sm:col-span-2" : "text-sm text-muted-foreground sm:col-span-2"}>{state.message}</p> : null}</form>;
}
