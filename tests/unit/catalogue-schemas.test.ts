import { describe, expect, it } from "vitest";

import { catalogItemSchema, itemCategorySchema, unitConversionSchema, unitOfMeasureSchema } from "@/features/master-data/schemas";

const organisationId = "10000000-0000-4000-8000-000000000001";
const unitId = "10000000-0000-4000-8000-000000000002";
const otherUnitId = "10000000-0000-4000-8000-000000000003";

describe("catalogue schemas", () => {
  it("normalises tenant item category and unit codes", () => {
    expect(itemCategorySchema.parse({ organisationId, code: "raw-material", name: "Raw material" }).code).toBe("RAW-MATERIAL");
    expect(unitOfMeasureSchema.parse({ organisationId, code: "kg", name: "Kilogram", dimension: "weight", decimalPlaces: "3" }).code).toBe("KG");
  });

  it("requires a positive conversion between different units", () => {
    expect(unitConversionSchema.safeParse({ organisationId, fromUnitId: unitId, toUnitId: unitId, factor: "1" }).success).toBe(false);
    expect(unitConversionSchema.safeParse({ organisationId, fromUnitId: unitId, toUnitId: otherUnitId, factor: "0" }).success).toBe(false);
    expect(unitConversionSchema.safeParse({ organisationId, fromUnitId: unitId, toUnitId: otherUnitId, factor: "1000" }).success).toBe(true);
  });

  it("does not allow services to track inventory", () => {
    const baseItem = { organisationId, baseUnitId: unitId, code: "consulting", name: "Consulting", description: "", isActive: "true" };
    expect(catalogItemSchema.safeParse({ ...baseItem, itemType: "service", tracksInventory: "true" }).success).toBe(false);
    expect(catalogItemSchema.safeParse({ ...baseItem, itemType: "product", tracksInventory: "true" }).success).toBe(true);
  });
});
