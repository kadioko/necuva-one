"use server";

import { getServerEnvironment } from "@/lib/env";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

import { provisionOrganisationSchema } from "./schemas";

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
