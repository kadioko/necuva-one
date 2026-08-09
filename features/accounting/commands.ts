"use server";

import { revalidatePath } from "next/cache";

import type { PlatformActionState } from "@/features/platform/commands";
import { createClient } from "@/lib/supabase/server";

import { prepareDraftJournalCommand } from "./journal-draft";
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

export async function createDraftJournal(_previousState: PlatformActionState, formData: FormData): Promise<PlatformActionState> {
  void _previousState;

  let lines: unknown;
  try {
    lines = JSON.parse(String(formData.get("lines") ?? ""));
  } catch {
    return { status: "error", message: "Journal lines are invalid." };
  }

  const rawInput = { ...Object.fromEntries(formData), lines };
  const companyId = String(formData.get("companyId") ?? "");
  const supabase = await createClient();
  const { data: company } = await supabase
    .from("companies")
    .select("currency_code")
    .eq("id", companyId)
    .maybeSingle();

  if (!company) return { status: "error", message: "The selected legal company is unavailable." };

  const { data: currency } = await supabase
    .from("currencies")
    .select("decimal_places")
    .eq("code", company.currency_code)
    .eq("is_active", true)
    .maybeSingle();

  if (!currency) return { status: "error", message: "The company currency is unavailable." };

  let input;
  try {
    input = prepareDraftJournalCommand(rawInput, currency.decimal_places);
  } catch (error) {
    return { status: "error", message: error instanceof Error ? error.message : "Draft journal input is invalid." };
  }

  const { data: journalId, error } = await supabase.rpc("create_draft_journal", { input });
  if (error || !journalId) {
    return { status: "error", message: "Draft journal could not be created. Check the branch, date, accounts, and balance." };
  }

  const { data: journal } = await supabase
    .from("accounting_journals")
    .select("journal_number")
    .eq("id", journalId)
    .maybeSingle();

  revalidatePath("/erp/accounting/journals");
  return { status: "success", message: journal?.journal_number ? `Draft ${journal.journal_number} created and audited.` : "Draft journal created and audited." };
}
