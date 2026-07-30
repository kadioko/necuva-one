import { createClient } from "@/lib/supabase/server";

type AuditPageProps = { searchParams: Promise<{ action?: string; from?: string; organisationId?: string; to?: string }> };

export default async function AuditPage({ searchParams }: AuditPageProps) {
  const { action, from, organisationId, to } = await searchParams;
  const supabase = await createClient();
  let eventsQuery = supabase.from("audit_events").select("id, action, entity_type, entity_id, occurred_at, reason").order("occurred_at", { ascending: false }).limit(50);
  if (organisationId) eventsQuery = eventsQuery.eq("organisation_id", organisationId);
  if (action) eventsQuery = eventsQuery.eq("action", action);
  if (from) eventsQuery = eventsQuery.gte("occurred_at", from);
  if (to) eventsQuery = eventsQuery.lte("occurred_at", to);
  const events = organisationId ? await eventsQuery : { data: [], error: null };
  const exportQuery = new URLSearchParams({ organisationId: organisationId ?? "" });
  if (action) exportQuery.set("action", action);
  if (from) exportQuery.set("from", from);
  if (to) exportQuery.set("to", to);

  return <section className="space-y-6"><div><p className="text-sm font-medium text-muted-foreground">Organisation settings</p><h1 className="mt-1 text-2xl font-semibold">Audit trail</h1><p className="mt-2 text-sm leading-6 text-muted-foreground">Recent recorded administrative events for an organisation you are authorised to audit.</p></div><form className="grid max-w-3xl gap-3 sm:grid-cols-2" method="get"><input className="h-10 rounded-md border bg-background px-3 text-sm sm:col-span-2" defaultValue={organisationId} name="organisationId" placeholder="Organisation ID" required /><input className="h-10 rounded-md border bg-background px-3 text-sm" defaultValue={action} name="action" placeholder="Action (optional)" /><input className="h-10 rounded-md border bg-background px-3 text-sm" defaultValue={from} name="from" placeholder="From (ISO timestamp)" /><input className="h-10 rounded-md border bg-background px-3 text-sm" defaultValue={to} name="to" placeholder="To (ISO timestamp)" /><div className="flex gap-2"><button className="h-10 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground" type="submit">Search</button>{organisationId ? <a className="inline-flex h-10 items-center rounded-md border px-4 text-sm font-medium" href={`/erp/audit/export?${exportQuery.toString()}`}>Export CSV</a> : null}</div></form>{events.error ? <p className="text-sm text-destructive">Audit events could not be loaded.</p> : <div className="overflow-x-auto border"><table className="w-full text-left text-sm"><thead className="bg-muted text-muted-foreground"><tr><th className="p-3">When</th><th className="p-3">Action</th><th className="p-3">Entity</th><th className="p-3">Reason</th></tr></thead><tbody>{events.data?.length ? events.data.map((event) => <tr className="border-t" key={event.id}><td className="p-3">{new Date(event.occurred_at).toLocaleString("en-TZ")}</td><td className="p-3">{event.action}</td><td className="p-3">{event.entity_type}</td><td className="p-3">{event.reason ?? "-"}</td></tr>) : <tr><td className="p-3 text-muted-foreground" colSpan={4}>No audit events found.</td></tr>}</tbody></table></div>}</section>;
}
