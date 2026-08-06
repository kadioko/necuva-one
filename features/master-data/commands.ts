"use server";

import { createClient } from "@/lib/supabase/server";

import type { PlatformActionState } from "@/features/platform/commands";
import { businessPartyAddressSchema, businessPartyCategorySchema, businessPartyContactSchema, businessPartySchema, configurationApprovalSchema, currencySchema, exchangeRateSchema, taxConfigurationSchema } from "./schemas";

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
