"use server";

import { getServerEnvironment } from "@/lib/env";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

import { organisationMembershipSchema, organisationStructureSchema, provisionOrganisationSchema, supportAccessSchema } from "./schemas";

export type PlatformActionState = {
  status: "idle" | "success" | "error";
  message?: string;
};

export const initialPlatformActionState: PlatformActionState = { status: "idle" };

export async function bootstrapPlatformOwner(
  _previousState: PlatformActionState,
  _formData: FormData,
): Promise<PlatformActionState> {
  void _previousState;
  void _formData;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    return { status: "error", message: "Sign in before bootstrapping the platform owner." };
  }

  const environment = getServerEnvironment();
  if (!environment.NECUVA_BOOTSTRAP_EMAILS.includes(user.email.toLowerCase())) {
    return { status: "error", message: "This account is not authorised for platform bootstrap." };
  }

  const admin = createAdminClient();
  const { error } = await admin.rpc("bootstrap_platform_owner", { target_user_id: user.id });

  if (error) {
    return { status: "error", message: "Platform owner bootstrap could not be completed." };
  }

  return { status: "success", message: "Platform owner access has been granted." };
}

export async function provisionOrganisation(
  _previousState: PlatformActionState,
  formData: FormData,
): Promise<PlatformActionState> {
  void _previousState;
  const parsed = provisionOrganisationSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: "Review the organisation details and try again." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return { status: "error", message: "Sign in before provisioning an organisation." };
  }

  const { error } = await supabase.rpc("provision_organisation", { input: parsed.data });
  if (error) {
    return { status: "error", message: "Organisation provisioning could not be completed." };
  }

  return { status: "success", message: "Organisation provisioned with its first company and branch." };
}

export async function addOrganisationStructure(
  _previousState: PlatformActionState,
  formData: FormData,
): Promise<PlatformActionState> {
  void _previousState;
  const parsed = organisationStructureSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Review the structure details and try again." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("add_organisation_structure", { input: parsed.data });
  return error
    ? { status: "error", message: "The structure record could not be created." }
    : { status: "success", message: "Structure record created and audited." };
}

export async function manageOrganisationMembership(
  _previousState: PlatformActionState,
  formData: FormData,
): Promise<PlatformActionState> {
  void _previousState;
  const parsed = organisationMembershipSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Review the member details and try again." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("manage_organisation_membership", { input: parsed.data });
  return error
    ? { status: "error", message: "Membership could not be updated." }
    : { status: "success", message: "Membership and role assignment updated." };
}

export async function grantSupportAccess(_previousState: PlatformActionState, formData: FormData): Promise<PlatformActionState> {
  void _previousState;
  const parsed = supportAccessSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: "Review the support access details and try again." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("grant_support_access", { input: parsed.data });
  return error ? { status: "error", message: "Support access could not be granted." } : { status: "success", message: "Time-limited support access granted and audited." };
}

export async function revokeSupportAccess(_previousState: PlatformActionState, formData: FormData): Promise<PlatformActionState> {
  void _previousState;
  const grantId = formData.get("grantId");
  if (typeof grantId !== "string") return { status: "error", message: "Support grant is required." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("revoke_support_access", { grant_id: grantId, revoke_reason: String(formData.get("reason") ?? "") });
  return error ? { status: "error", message: "Support access could not be revoked." } : { status: "success", message: "Support access revoked and audited." };
}
