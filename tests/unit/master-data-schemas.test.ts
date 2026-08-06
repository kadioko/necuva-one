import { describe, expect, it } from "vitest";

import { currencySchema, exchangeRateSchema, taxConfigurationSchema } from "@/features/master-data/schemas";

const organisationId = "10000000-0000-4000-8000-000000000001";

describe("master-data schemas", () => {
  it("normalises ISO currency codes and validates decimal places", () => {
    expect(currencySchema.parse({ code: "usd", name: "US dollar", symbol: "$", decimalPlaces: "2", isActive: "true" }).code).toBe("USD");
    expect(currencySchema.safeParse({ code: "TZ", name: "Tanzanian shilling", symbol: "TZS", decimalPlaces: "5", isActive: "true" }).success).toBe(false);
  });

  it("requires positive, date-effective exchange rates", () => {
    expect(exchangeRateSchema.safeParse({ organisationId, currencyCode: "usd", effectiveOn: "2026-08-06", rate: "0", sourceReference: "Bank of Tanzania bulletin" }).success).toBe(false);
    expect(exchangeRateSchema.parse({ organisationId, currencyCode: "usd", effectiveOn: "2026-08-06", rate: "2565.2500", sourceReference: "Bank of Tanzania bulletin" }).currencyCode).toBe("USD");
  });

  it("rejects invalid tax date ranges and rates", () => {
    expect(taxConfigurationSchema.safeParse({ organisationId, code: "vat", name: "Value added tax", taxType: "vat", ratePercent: "18", effectiveFrom: "2026-08-06", effectiveTo: "2026-08-05", sourceReference: "Tanzania tax schedule" }).success).toBe(false);
    expect(taxConfigurationSchema.safeParse({ organisationId, code: "VAT", name: "Value added tax", taxType: "vat", ratePercent: "101", effectiveFrom: "2026-08-06", sourceReference: "Tanzania tax schedule" }).success).toBe(false);
  });
});
