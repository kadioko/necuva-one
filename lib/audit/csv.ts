type AuditExportEvent = {
  action: string;
  actor_user_id: string | null;
  after_state: unknown;
  before_state: unknown;
  entity_id: string | null;
  entity_type: string;
  occurred_at: string;
  reason: string | null;
};

const headers = ["occurred_at", "action", "entity_type", "entity_id", "actor_user_id", "reason", "before_state", "after_state"];

function escapeCsvCell(value: unknown) {
  const text = value === null || value === undefined ? "" : typeof value === "string" ? value : JSON.stringify(value);
  const safeText = /^[=+\-@]/.test(text) ? `'${text}` : text;
  return `"${safeText.replaceAll('"', '""')}"`;
}

export function auditEventsToCsv(events: AuditExportEvent[]) {
  const rows = events.map((event) => [event.occurred_at, event.action, event.entity_type, event.entity_id, event.actor_user_id, event.reason, event.before_state, event.after_state].map(escapeCsvCell).join(","));
  return `${headers.join(",")}\n${rows.join("\n")}\n`;
}
