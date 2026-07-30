import { describe, expect, it } from "vitest";

import { auditEventsToCsv } from "@/lib/audit/csv";

describe("auditEventsToCsv", () => {
  it("escapes quoted values and neutralises spreadsheet formulas", () => {
    const csv = auditEventsToCsv([{ action: "=HYPERLINK()", actor_user_id: null, after_state: { changed: true }, before_state: null, entity_id: null, entity_type: "organisation", occurred_at: "2026-07-30T12:00:00.000Z", reason: 'Quoted "reason"' }]);
    expect(csv).toContain("\"'=HYPERLINK()\"");
    expect(csv).toContain('"Quoted ""reason"""');
    expect(csv).toContain('"{""changed"":true}"');
  });
});
