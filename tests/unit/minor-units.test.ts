import { describe, expect, it } from "vitest";

import { formatMinorUnits, parseDecimalToMinorUnits, parseMinorUnits } from "@/lib/money/minor-units";

describe("parseMinorUnits", () => {
  it("accepts integer minor units without floating point conversion", () => {
    expect(parseMinorUnits("25000000")).toBe(25000000n);
  });

  it("rejects decimal values", () => {
    expect(() => parseMinorUnits("25.5")).toThrow("integer number of minor units");
  });

  it("converts currency decimals without floating point arithmetic", () => {
    expect(parseDecimalToMinorUnits("123456789.05", 2)).toBe(12345678905n);
    expect(formatMinorUnits(12345678905n, 2)).toBe("123456789.05");
  });

  it("honours zero-decimal currencies", () => {
    expect(parseDecimalToMinorUnits("25000", 0)).toBe(25000n);
    expect(() => parseDecimalToMinorUnits("25000.50", 0)).toThrow("at most 0 decimal places");
  });
});
