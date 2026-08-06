"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";

import { approveExchangeRateVersion, approveTaxConfigurationVersion, initialMasterDataActionState } from "../commands";

export function ConfigurationApprovalButton({ id, kind }: { id: string; kind: "exchange-rate" | "tax" }) {
  const serverAction = kind === "exchange-rate" ? approveExchangeRateVersion : approveTaxConfigurationVersion;
  const [state, action, pending] = useActionState(serverAction, initialMasterDataActionState);
  return <form action={action} className="flex items-center gap-2"><input name="id" type="hidden" value={id} /><Button disabled={pending} size="sm" type="submit">{pending ? "Approving..." : "Approve"}</Button>{state.status === "error" ? <span className="text-xs text-destructive">{state.message}</span> : null}</form>;
}
