import "server-only";

import { createClient } from "@supabase/supabase-js";

import { getServiceRoleEnvironment } from "@/lib/env";

export function createAdminClient() {
  const environment = getServiceRoleEnvironment();

  return createClient(
    environment.NEXT_PUBLIC_SUPABASE_URL,
    environment.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}
