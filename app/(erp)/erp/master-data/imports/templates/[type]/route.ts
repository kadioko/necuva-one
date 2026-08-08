import { createClient } from "@/lib/supabase/server";
import { importTemplate, type MasterDataImportType } from "@/features/imports/csv";

const supportedTypes = new Set<MasterDataImportType>(["business_parties", "catalog_items"]);

export async function GET(_request: Request, { params }: { params: Promise<{ type: string }> }) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response("Authentication required.", { status: 401 });
  const { type } = await params;
  if (!supportedTypes.has(type as MasterDataImportType)) return new Response("Unknown import template.", { status: 404 });
  return new Response(importTemplate(type as MasterDataImportType), {
    headers: {
      "Content-Disposition": `attachment; filename="${type}-template.csv"`,
      "Content-Type": "text/csv; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
