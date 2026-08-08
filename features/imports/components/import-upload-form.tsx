"use client";

import Link from "next/link";
import { Download, Upload } from "lucide-react";
import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";

import { initialImportActionState, stageMasterDataImport } from "../commands";

export function ImportUploadForm({ organisationId }: { organisationId: string }) {
  const [state, action, pending] = useActionState(stageMasterDataImport, initialImportActionState);
  return <form action={action} className="grid gap-4 border-t pt-6 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><label className="grid gap-2"><Label htmlFor="importType">Import type</Label><select className="h-10 rounded-md border bg-background px-3 text-sm" id="importType" name="importType"><option value="business_parties">Customers and suppliers</option><option value="catalog_items">Catalogue items</option></select></label><label className="grid gap-2"><Label htmlFor="importFile">CSV file</Label><input accept=".csv,text/csv" className="h-10 rounded-md border bg-background px-3 py-2 text-sm file:mr-3 file:border-0 file:bg-transparent file:text-sm file:font-medium" id="importFile" name="file" required type="file" /></label><div className="flex flex-wrap gap-2 sm:col-span-2"><Button disabled={pending} type="submit"><Upload aria-hidden="true" />{pending ? "Staging..." : "Stage import"}</Button><Button asChild type="button" variant="outline"><Link href="/erp/master-data/imports/templates/business_parties"><Download aria-hidden="true" />Party template</Link></Button><Button asChild type="button" variant="outline"><Link href="/erp/master-data/imports/templates/catalog_items"><Download aria-hidden="true" />Catalogue template</Link></Button></div>{state.message ? <p className={state.status === "error" ? "text-sm text-destructive sm:col-span-2" : "text-sm text-muted-foreground sm:col-span-2"}>{state.message}{state.importId ? <> <Link className="font-medium underline" href={`/erp/master-data/imports?organisationId=${organisationId}&importId=${state.importId}`}>Open preview</Link></> : null}</p> : null}</form>;
}
