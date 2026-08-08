import { describe, expect, it } from "vitest";

import { bankAccountSchema, mobileMoneyAccountSchema, paymentMethodSchema } from "@/features/master-data/schemas";

const organisationId = "10000000-0000-4000-8000-000000000001";
const companyId = "10000000-0000-4000-8000-000000000002";

describe("payment-reference schemas", () => {
  it("normalises payment method codes", () => {
    const result = paymentMethodSchema.parse({ organisationId, companyId, code: "bank-transfer", name: "Bank transfer", kind: "bank_transfer", instructions: "", isActive: "true" });
    expect(result.code).toBe("BANK-TRANSFER");
    expect(result.instructions).toBeUndefined();
  });

  it("validates bank identifiers and default status", () => {
    const base = { organisationId, companyId, code: "nmb-tzs", name: "NMB TZS", bankName: "NMB Bank", accountName: "Necuva Limited", accountNumber: "00123456789", branchName: "", currencyCode: "tzs", isDefault: "true" };
    expect(bankAccountSchema.safeParse({ ...base, swiftCode: "NLCBTZTX", isActive: "true" }).success).toBe(true);
    expect(bankAccountSchema.safeParse({ ...base, swiftCode: "BAD", isActive: "true" }).success).toBe(false);
    expect(bankAccountSchema.safeParse({ ...base, swiftCode: "", isActive: "false" }).success).toBe(false);
  });

  it("requires an international-style numeric mobile number", () => {
    const base = { organisationId, companyId, code: "mobile-tzs", name: "Mobile collections", providerName: "Provider", accountName: "Necuva Limited", currencyCode: "TZS", isDefault: "false", isActive: "true" };
    expect(mobileMoneyAccountSchema.safeParse({ ...base, phoneNumber: "+255712345678" }).success).toBe(true);
    expect(mobileMoneyAccountSchema.safeParse({ ...base, phoneNumber: "+255 712 345 678" }).success).toBe(false);
  });
});
