import { describe, expect, it } from "vitest";

import { prepareDraftJournalCommand } from "@/features/accounting/journal-draft";

const baseInput = {
  organisationId: "10000000-0000-4000-8000-000000000001",
  companyId: "10000000-0000-4000-8000-000000000002",
  branchId: "10000000-0000-4000-8000-000000000003",
  journalDate: "2026-08-09",
  description: "Bank fee accrual",
  sourceReference: "BANK-2026-08-09",
  lines: [
    { accountId: "10000000-0000-4000-8000-000000000004", description: "Bank fee", debit: "125.50", credit: "" },
    { accountId: "10000000-0000-4000-8000-000000000005", description: "Payable", debit: "", credit: "125.50" },
  ],
};

describe("draft journal preparation", () => {
  it("normalises balanced decimal amounts into integer minor-unit strings", () => {
    const command = prepareDraftJournalCommand(baseInput, 2);
    expect(command.lines[0].debitMinor).toBe("12550");
    expect(command.lines[1].creditMinor).toBe("12550");
  });

  it("rejects an unbalanced journal", () => {
    const input = { ...baseInput, lines: [baseInput.lines[0], { ...baseInput.lines[1], credit: "125.49" }] };
    expect(() => prepareDraftJournalCommand(input, 2)).toThrow("must balance");
  });

  it("requires exactly one positive side on every line", () => {
    const input = { ...baseInput, lines: [{ ...baseInput.lines[0], credit: "1.00" }, baseInput.lines[1]] };
    expect(() => prepareDraftJournalCommand(input, 2)).toThrow("exactly one positive amount");
  });

  it("applies the company currency precision", () => {
    expect(() => prepareDraftJournalCommand(baseInput, 0)).toThrow("at most 0 decimal places");
  });
});
