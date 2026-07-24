import { describe, expect, it } from "vitest";

import { parseMinorUnits } from "@/lib/money/minor-units";

describe("parseMinorUnits", () => {
  it("accepts integer minor units without floating point conversion", () => {
    expect(parseMinorUnits("25000000")).toBe(25000000n);
  });

  it("rejects decimal values", () => {
    expect(() => parseMinorUnits("25.5")).toThrow("integer number of minor units");
  });
});
