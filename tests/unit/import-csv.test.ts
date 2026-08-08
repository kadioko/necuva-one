import { describe, expect, it } from "vitest";

import { ImportCsvError, importTemplate, parseMasterDataCsv } from "@/features/imports/csv";

describe("master-data CSV parsing", () => {
  it("publishes stable header-only templates", () => {
    expect(importTemplate("business_parties")).toBe("external_code,display_name,party_type,legal_name,tax_identification_number,email,phone,is_active\r\n");
    expect(importTemplate("catalog_items")).toContain("base_unit_code,category_code");
  });

  it("parses quoted values and maps headers to the import contract", () => {
    const source = "external_code,display_name,party_type,legal_name,tax_identification_number,email,phone,is_active\nACME,\"Acme, Limited\",customer,,,,,true\n";
    expect(parseMasterDataCsv("business_parties", source)).toEqual([{ rowNumber: 2, data: { externalCode: "ACME", displayName: "Acme, Limited", partyType: "customer", legalName: "", taxIdentificationNumber: "", email: "", phone: "", isActive: "true" } }]);
  });

  it("rejects reordered, missing, and inconsistent columns", () => {
    expect(() => parseMasterDataCsv("catalog_items", "name,code\nRice,RICE\n")).toThrow(ImportCsvError);
    expect(() => parseMasterDataCsv("business_parties", "external_code,display_name,party_type,legal_name,tax_identification_number,email,phone,is_active\nACME,Acme,customer\n")).toThrow("malformed or has inconsistent columns");
  });
});
