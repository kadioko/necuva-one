import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";

import { auditEventsToCsv } from "@/lib/audit/csv";
import { createClient } from "@/lib/supabase/server";
import { uuidSchema } from "@/lib/validation/common";

const exportQuerySchema = z.object({
  organisationId: uuidSchema,
  action: z.string().trim().max(150).optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
}).refine((value) => !value.from || !value.to || value.from <= value.to, { message: "The date range is invalid." });

export async function GET(request: NextRequest) {
  const parsed = exportQuerySchema.safeParse({
    organisationId: request.nextUrl.searchParams.get("organisationId"),
    action: request.nextUrl.searchParams.get("action") || undefined,
    from: request.nextUrl.searchParams.get("from") || undefined,
    to: request.nextUrl.searchParams.get("to") || undefined,
  });
  if (!parsed.success) return NextResponse.json({ error: "Invalid audit export filters." }, { status: 400 });

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Authentication is required." }, { status: 401 });

  let query = supabase
    .from("audit_events")
    .select("action, actor_user_id, after_state, before_state, entity_id, entity_type, occurred_at, reason")
    .eq("organisation_id", parsed.data.organisationId)
    .order("occurred_at", { ascending: false })
    .limit(5000);

  if (parsed.data.action) query = query.eq("action", parsed.data.action);
  if (parsed.data.from) query = query.gte("occurred_at", parsed.data.from);
  if (parsed.data.to) query = query.lte("occurred_at", parsed.data.to);

  const { data: events, error } = await query;
  if (error) return NextResponse.json({ error: "Audit events could not be exported." }, { status: 403 });

  return new NextResponse(auditEventsToCsv(events ?? []), {
    headers: {
      "Content-Disposition": `attachment; filename="audit-${parsed.data.organisationId}.csv"`,
      "Content-Type": "text/csv; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}
