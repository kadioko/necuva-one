"use server";

import { createClient } from "@/lib/supabase/server";

import type { PlatformActionState } from "@/features/platform/commands";
import { bankAccountSchema, businessPartyAddressSchema, businessPartyCategorySchema, businessPartyContactSchema, businessPartySchema, catalogItemBarcodeSchema, catalogItemSchema, configurationApprovalSchema, currencySchema, exchangeRateSchema, itemCategorySchema, mobileMoneyAccountSchema, paymentMethodSchema, taxConfigurationSchema, unitConversionSchema, unitOfMeasureSchema } from "./schemas";

export const initialMasterDataActionState: PlatformActionState = { status: "idle" };

export async function upsertCurrency(_previousState: PlatformActionState, formData: FormData): Promise<PlatformActionState> {
  void _previousState;
  const parsed = currencySchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Review the currency details and try again." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("upsert_currency", { input: parsed.data });
  return error ? { status: "error", message: "Currency could not be saved." } : { status: "success", message: "Currency saved and audited." };
}

export async function createExchangeRateVersion(_previousState: PlatformActionState, formData: FormData): Promise<PlatformActionState> {
  void _previousState;
  const parsed = exchangeRateSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Review the exchange-rate details and try again." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("create_exchange_rate_version", { input: parsed.data });
  return error ? { status: "error", message: "Exchange-rate version could not be created." } : { status: "success", message: "Exchange-rate draft created and audited." };
}

export async function createTaxConfigurationVersion(_previousState: PlatformActionState, formData: FormData): Promise<PlatformActionState> {
  void _previousState;
  const parsed = taxConfigurationSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Review the tax configuration details and try again." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("create_tax_configuration_version", { input: parsed.data });
  return error ? { status: "error", message: "Tax configuration draft could not be created." } : { status: "success", message: "Tax configuration draft created and audited." };
}

export async function approveExchangeRateVersion(_previousState: PlatformActionState, formData: FormData): Promise<PlatformActionState> {
  void _previousState;
  const parsed = configurationApprovalSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Exchange-rate version is required." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("approve_exchange_rate_version", { target_id: parsed.data.id });
  return error ? { status: "error", message: "Exchange-rate version could not be approved." } : { status: "success", message: "Exchange-rate version approved and audited." };
}

export async function approveTaxConfigurationVersion(_previousState: PlatformActionState, formData: FormData): Promise<PlatformActionState> {
  void _previousState;
  const parsed = configurationApprovalSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Tax configuration version is required." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("approve_tax_configuration_version", { target_id: parsed.data.id });
  return error ? { status: "error", message: "Tax configuration version could not be approved." } : { status: "success", message: "Tax configuration version approved and audited." };
}

export async function createBusinessPartyCategory(_previousState: PlatformActionState, formData: FormData): Promise<PlatformActionState> {
  void _previousState;
  const parsed = businessPartyCategorySchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Review the category details and try again." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("create_business_party_category", { input: parsed.data });
  return error ? { status: "error", message: "Party category could not be created." } : { status: "success", message: "Party category created and audited." };
}

export async function upsertBusinessParty(_previousState: PlatformActionState, formData: FormData): Promise<PlatformActionState> {
  void _previousState;
  const parsed = businessPartySchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Review the party details and try again." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("upsert_business_party", { input: parsed.data });
  return error ? { status: "error", message: "Business party could not be saved." } : { status: "success", message: "Business party saved and audited." };
}

export async function addBusinessPartyContact(_previousState: PlatformActionState, formData: FormData): Promise<PlatformActionState> {
  void _previousState;
  const parsed = businessPartyContactSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Review the contact details and try again." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("add_business_party_contact", { input: parsed.data });
  return error ? { status: "error", message: "Party contact could not be added." } : { status: "success", message: "Party contact added and audited." };
}

export async function addBusinessPartyAddress(_previousState: PlatformActionState, formData: FormData): Promise<PlatformActionState> {
  void _previousState;
  const parsed = businessPartyAddressSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Review the address details and try again." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("add_business_party_address", { input: parsed.data });
  return error ? { status: "error", message: "Party address could not be added." } : { status: "success", message: "Party address added and audited." };
}

type FormSchema = { safeParse: (data: unknown) => { success: true; data: object } | { success: false } };

async function runMasterDataCommand(formData: FormData, schema: FormSchema, rpc: string, failureMessage: string, successMessage: string): Promise<PlatformActionState> {
  const parsed = schema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: failureMessage };
  const supabase = await createClient();
  const { error } = await supabase.rpc(rpc, { input: parsed.data });
  return error ? { status: "error", message: failureMessage } : { status: "success", message: successMessage };
}

export async function createItemCategory(_previousState: PlatformActionState, formData: FormData) { void _previousState; return runMasterDataCommand(formData, itemCategorySchema, "create_item_category", "Item category could not be created.", "Item category created and audited."); }
export async function createUnitOfMeasure(_previousState: PlatformActionState, formData: FormData) { void _previousState; return runMasterDataCommand(formData, unitOfMeasureSchema, "create_unit_of_measure", "Unit of measure could not be created.", "Unit of measure created and audited."); }
export async function createUnitConversion(_previousState: PlatformActionState, formData: FormData) { void _previousState; return runMasterDataCommand(formData, unitConversionSchema, "create_unit_conversion", "Unit conversion could not be created.", "Unit conversion created and audited."); }
export async function upsertCatalogItem(_previousState: PlatformActionState, formData: FormData) { void _previousState; return runMasterDataCommand(formData, catalogItemSchema, "upsert_catalog_item", "Catalogue item could not be saved.", "Catalogue item saved and audited."); }
export async function addCatalogItemBarcode(_previousState: PlatformActionState, formData: FormData) { void _previousState; return runMasterDataCommand(formData, catalogItemBarcodeSchema, "add_catalog_item_barcode", "Item barcode could not be added.", "Item barcode added and audited."); }
export async function upsertPaymentMethod(_previousState: PlatformActionState, formData: FormData) { void _previousState; return runMasterDataCommand(formData, paymentMethodSchema, "upsert_payment_method", "Payment method could not be saved.", "Payment method saved and audited."); }
export async function upsertBankAccount(_previousState: PlatformActionState, formData: FormData) { void _previousState; return runMasterDataCommand(formData, bankAccountSchema, "upsert_bank_account", "Bank account could not be saved.", "Bank account saved and audited."); }
export async function upsertMobileMoneyAccount(_previousState: PlatformActionState, formData: FormData) { void _previousState; return runMasterDataCommand(formData, mobileMoneyAccountSchema, "upsert_mobile_money_account", "Mobile-money account could not be saved.", "Mobile-money account saved and audited."); }
