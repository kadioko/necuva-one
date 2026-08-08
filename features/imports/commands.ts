"use server";

import { Buffer } from "node:buffer";
import { createHash } from "node:crypto";
import { revalidatePath } from "next/cache";

import { createClient } from "@/lib/supabase/server";

import { ImportCsvError, parseMasterDataCsv } from "./csv";
import { confirmImportSchema, stageImportSchema } from "./schemas";

export type ImportActionState = { status: "idle" | "success" | "error"; message?: string; importId?: string };
export const initialImportActionState: ImportActionState = { status: "idle" };

export async function stageMasterDataImport(_previousState: ImportActionState, formData: FormData): Promise<ImportActionState> {
  void _previousState;
  const parsed = stageImportSchema.safeParse(Object.fromEntries(formData));
  const file = formData.get("file");
  if (!parsed.success || !(file instanceof File)) return { status: "error", message: "Choose an import type and CSV file." };
  if (!file.name.toLowerCase().endsWith(".csv") || file.size === 0 || file.size > 1_000_000) return { status: "error", message: "Use a non-empty CSV file no larger than 1 MB." };

  let rows;
  try {
    rows = parseMasterDataCsv(parsed.data.importType, await file.text());
  } catch (error) {
    return { status: "error", message: error instanceof ImportCsvError ? error.message : "The CSV file could not be parsed." };
  }
  if (rows.length === 0 || rows.length > 500) return { status: "error", message: "The CSV must contain between 1 and 500 data rows." };

  const safeFileName = file.name.split(/[\\/]/).pop()?.slice(0, 255) || "import.csv";
  const fileChecksum = createHash("sha256").update(Buffer.from(await file.arrayBuffer())).digest("hex");
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("stage_master_data_import", { input: { ...parsed.data, fileName: safeFileName, fileChecksum, rows } });
  if (error) return { status: "error", message: error.code === "23505" ? "This exact file has already been staged for the selected import type." : "The import could not be staged." };
  revalidatePath("/erp/master-data/imports");
  return { status: "success", message: "Import staged. Review every invalid and update row before confirmation.", importId: data as string };
}

export async function confirmMasterDataImport(_previousState: ImportActionState, formData: FormData): Promise<ImportActionState> {
  void _previousState;
  const parsed = confirmImportSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Select a valid staged import." };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("confirm_master_data_import", { target_id: parsed.data.importId });
  if (error) return { status: "error", message: "The import could not be confirmed. Resolve invalid rows and verify permissions." };
  revalidatePath("/erp/master-data/imports");
  return { status: "success", message: `${data as number} rows were applied atomically and audited.`, importId: parsed.data.importId };
}
