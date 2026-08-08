import Link from "next/link";

import { ConfirmImportButton } from "@/features/imports/components/confirm-import-button";
import { ImportUploadForm } from "@/features/imports/components/import-upload-form";
import { createClient } from "@/lib/supabase/server";

type ImportsPageProps = { searchParams: Promise<{ importId?: string; organisationId?: string }> };

function recordValue(value: unknown, key: string) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return "-";
  const field = (value as Record<string, unknown>)[key];
  return typeof field === "string" && field ? field : "-";
}

export default async function ImportsPage({ searchParams }: ImportsPageProps) {
  const { importId, organisationId: requestedOrganisationId } = await searchParams;
  const supabase = await createClient();
  const { data: context } = await supabase.from("user_tenant_contexts").select("organisation_id").maybeSingle();
  const organisationId = requestedOrganisationId ?? context?.organisation_id;
  const { data: imports } = organisationId
    ? await supabase.from("master_data_imports").select("id, import_type, file_name, status, total_rows, create_rows, update_rows, invalid_rows, created_at, confirmed_at").eq("organisation_id", organisationId).order("created_at", { ascending: false }).limit(25)
    : { data: [] };
  const selectedImport = importId && organisationId
    ? (await supabase.from("master_data_imports").select("id, import_type, file_name, status, total_rows, create_rows, update_rows, invalid_rows, created_at, confirmed_at").eq("organisation_id", organisationId).eq("id", importId).maybeSingle()).data
    : null;
  const rows = selectedImport
    ? (await supabase.from("master_data_import_rows").select("id, row_number, operation, raw_data, validation_errors").eq("organisation_id", organisationId!).eq("import_id", selectedImport.id).order("row_number")).data ?? []
    : [];

  return <section className="max-w-6xl space-y-8"><div><p className="text-sm font-medium text-muted-foreground">Master data</p><h1 className="mt-1 text-2xl font-semibold">Controlled imports</h1><p className="mt-2 text-sm leading-6 text-muted-foreground">Stage CSV data, review creates, updates, and validation errors, then confirm one atomic audited batch.</p></div><form className="flex max-w-xl gap-2" method="get"><input className="h-10 min-w-0 flex-1 rounded-md border bg-background px-3 text-sm" defaultValue={organisationId ?? ""} name="organisationId" placeholder="Organisation ID" required /><button className="h-10 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground" type="submit">Load</button></form>{organisationId ? <><ImportUploadForm organisationId={organisationId} /><section className="space-y-4 border-t pt-6"><h2 className="text-lg font-semibold">Import history</h2><div className="overflow-x-auto border"><table className="w-full text-left text-sm"><thead className="bg-muted text-muted-foreground"><tr><th className="p-3">File</th><th className="p-3">Type</th><th className="p-3">Rows</th><th className="p-3">Creates</th><th className="p-3">Updates</th><th className="p-3">Invalid</th><th className="p-3">Status</th></tr></thead><tbody>{imports?.length ? imports.map((batch) => <tr className="border-t" key={batch.id}><td className="p-3"><Link className="font-medium underline-offset-4 hover:underline" href={`/erp/master-data/imports?organisationId=${organisationId}&importId=${batch.id}`}>{batch.file_name}</Link></td><td className="p-3">{batch.import_type.replaceAll("_", " ")}</td><td className="p-3">{batch.total_rows}</td><td className="p-3">{batch.create_rows}</td><td className="p-3">{batch.update_rows}</td><td className={batch.invalid_rows ? "p-3 font-medium text-destructive" : "p-3"}>{batch.invalid_rows}</td><td className="p-3">{batch.status}</td></tr>) : <tr><td className="p-3 text-muted-foreground" colSpan={7}>No import batches found.</td></tr>}</tbody></table></div></section>{selectedImport ? <section className="space-y-4 border-t pt-6"><div className="flex flex-wrap items-start justify-between gap-4"><div><h2 className="text-lg font-semibold">Preview: {selectedImport.file_name}</h2><p className="mt-1 text-sm text-muted-foreground">{selectedImport.create_rows} creates, {selectedImport.update_rows} updates, {selectedImport.invalid_rows} invalid</p></div><ConfirmImportButton disabled={selectedImport.status !== "staged" || selectedImport.invalid_rows > 0} importId={selectedImport.id} /></div><div className="overflow-x-auto border"><table className="w-full text-left text-sm"><thead className="bg-muted text-muted-foreground"><tr><th className="p-3">Line</th><th className="p-3">Operation</th><th className="p-3">Code</th><th className="p-3">Name</th><th className="p-3">Validation</th></tr></thead><tbody>{rows.map((row) => <tr className="border-t align-top" key={row.id}><td className="p-3">{row.row_number}</td><td className="p-3">{row.operation}</td><td className="p-3 font-mono text-xs">{recordValue(row.raw_data, selectedImport.import_type === "business_parties" ? "externalCode" : "code")}</td><td className="p-3">{recordValue(row.raw_data, selectedImport.import_type === "business_parties" ? "displayName" : "name")}</td><td className={row.validation_errors.length ? "p-3 text-destructive" : "p-3 text-muted-foreground"}>{row.validation_errors.length ? row.validation_errors.join(" ") : "Ready"}</td></tr>)}</tbody></table></div></section> : null}</> : <p className="text-sm text-muted-foreground">Set a workspace context or provide an organisation ID to manage imports.</p>}</section>;
}
