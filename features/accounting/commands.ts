"use server";

import { revalidatePath } from "next/cache";

import type { PlatformActionState } from "@/features/platform/commands";
import { createClient } from "@/lib/supabase/server";

import { accountGroupSchema, chartAccountSchema, fiscalYearSchema } from "./schemas";

export const initialAccountingActionState: PlatformActionState = { status: "idle" };

async function runAccountingCommand(formData: FormData, schema: { safeParse: (data: unknown) => { success: true; data: object } | { success: false } }, rpc: string, failureMessage: string, successMessage: string): Promise<PlatformActionState> {
  const parsed = schema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: failureMessage };
  const supabase = await createClient();
  const { error } = await supabase.rpc(rpc, { input: parsed.data });
  if (error) return { status: "error", message: failureMessage };
  revalidatePath("/erp/accounting/setup");
  return { status: "success", message: successMessage };
}

export async function createAccountGroup(_previousState: PlatformActionState, formData: FormData) {
  void _previousState;
  return runAccountingCommand(formData, accountGroupSchema, "create_account_group", "Account group could not be created.", "Account group created and audited.");
}

export async function upsertChartAccount(_previousState: PlatformActionState, formData: FormData) {
  void _previousState;
  return runAccountingCommand(formData, chartAccountSchema, "upsert_chart_account", "Chart account could not be saved.", "Chart account saved and audited.");
}

export async function createFiscalYear(_previousState: PlatformActionState, formData: FormData) {
  void _previousState;
  return runAccountingCommand(formData, fiscalYearSchema, "create_fiscal_year", "Fiscal year could not be created. Check the dates for overlap.", "Draft fiscal year and 12 future periods created.");
}
