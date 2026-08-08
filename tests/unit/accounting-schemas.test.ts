import { describe, expect, it } from "vitest";

import { accountGroupSchema, chartAccountSchema, fiscalYearSchema } from "@/features/accounting/schemas";

const organisationId = "10000000-0000-4000-8000-000000000001";
const companyId = "10000000-0000-4000-8000-000000000002";
const groupId = "10000000-0000-4000-8000-000000000003";

describe("accounting configuration schemas", () => {
  it("normalises chart and group codes", () => {
    expect(accountGroupSchema.parse({ organisationId, companyId, code: "1.10", name: "Current assets", accountType: "asset", description: "" }).code).toBe("1.10");
    expect(chartAccountSchema.parse({ organisationId, companyId, groupId, code: "cash-01", name: "Cash", accountType: "asset", description: "", isControlAccount: "false", allowManualPosting: "true", isActive: "true" }).code).toBe("CASH-01");
  });

  it("blocks manual posting to control accounts", () => {
    const input = { organisationId, companyId, groupId, code: "AR", name: "Trade receivables", accountType: "asset", description: "", isControlAccount: "true", isActive: "true" };
    expect(chartAccountSchema.safeParse({ ...input, allowManualPosting: "true" }).success).toBe(false);
    expect(chartAccountSchema.safeParse({ ...input, allowManualPosting: "false" }).success).toBe(true);
  });

  it("requires fiscal years to start on a month boundary", () => {
    expect(fiscalYearSchema.safeParse({ organisationId, companyId, name: "2026/2027", startDate: "2026-07-01" }).success).toBe(true);
    expect(fiscalYearSchema.safeParse({ organisationId, companyId, name: "Invalid", startDate: "2026-07-15" }).success).toBe(false);
  });
});
