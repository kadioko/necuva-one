"use client";

import { CheckCircle2 } from "lucide-react";
import { useActionState } from "react";

import { Button } from "@/components/ui/button";

import { confirmMasterDataImport, initialImportActionState } from "../commands";

export function ConfirmImportButton({ disabled, importId }: { disabled: boolean; importId: string }) {
  const [state, action, pending] = useActionState(confirmMasterDataImport, initialImportActionState);
  return <form action={action} className="space-y-2"><input name="importId" type="hidden" value={importId} /><Button disabled={disabled || pending} type="submit"><CheckCircle2 aria-hidden="true" />{pending ? "Confirming..." : "Confirm import"}</Button>{state.message ? <p className={state.status === "error" ? "text-sm text-destructive" : "text-sm text-muted-foreground"}>{state.message}</p> : null}</form>;
}
