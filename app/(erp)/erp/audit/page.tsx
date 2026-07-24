import { createClient } from "@/lib/supabase/server";

type AuditPageProps = { searchParams: Promise<{ organisationId?: string }> };

export default async function AuditPage({ searchParams }: AuditPageProps) {
  const { organisationId } = await searchParams;
  const supabase = await createClient();
  const events = organisationId
    ? await supabase.from("audit_events").select("id, action, entity_type, entity_id, occurred_at, reason").eq("organisation_id", organisationId).order("occurred_at", { ascending: false }).limit(50)
    : { data: [], error: null };

  return <section className="space-y-6"><div><p className="text-sm font-medium text-muted-foreground">Organisation settings</p><h1 className="mt-1 text-2xl font-semibold">Audit trail</h1><p className="mt-2 text-sm leading-6 text-muted-foreground">Recent recorded administrative events for an organisation you are authorised to audit.</p></div><form className="flex max-w-xl gap-2" method="get"><input className="h-10 min-w-0 flex-1 rounded-md border bg-background px-3 text-sm" defaultValue={organisationId} name="organisationId" placeholder="Organisation ID" required /><button className="h-10 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground" type="submit">Search</button></form>{events.error ? <p className="text-sm text-destructive">Audit events could not be loaded.</p> : <div className="overflow-x-auto border"><table className="w-full text-left text-sm"><thead className="bg-muted text-muted-foreground"><tr><th className="p-3">When</th><th className="p-3">Action</th><th className="p-3">Entity</th><th className="p-3">Reason</th></tr></thead><tbody>{events.data?.length ? events.data.map((event) => <tr className="border-t" key={event.id}><td className="p-3">{new Date(event.occurred_at).toLocaleString("en-TZ")}</td><td className="p-3">{event.action}</td><td className="p-3">{event.entity_type}</td><td className="p-3">{event.reason ?? "-"}</td></tr>) : <tr><td className="p-3 text-muted-foreground" colSpan={4}>No audit events found.</td></tr>}</tbody></table></div>}</section>;
}
