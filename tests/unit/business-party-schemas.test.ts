import { describe, expect, it } from "vitest";

import { businessPartyAddressSchema, businessPartyContactSchema, businessPartySchema } from "@/features/master-data/schemas";

const organisationId = "10000000-0000-4000-8000-000000000001";

describe("business-party schemas", () => {
  it("normalises a party code and email address", () => {
    const party = businessPartySchema.parse({ organisationId, partyType: "both", externalCode: " acme-01 ", displayName: "Acme Limited", legalName: "Acme Limited", email: "ACCOUNTS@ACME.TEST", phone: "", taxIdentificationNumber: "", categoryId: "", id: "", isActive: "true" });
    expect(party.externalCode).toBe("ACME-01");
    expect(party.email).toBe("accounts@acme.test");
  });

  it("requires a contact method for party contacts", () => {
    expect(businessPartyContactSchema.safeParse({ organisationId, partyId: organisationId, fullName: "Asha Mushi", jobTitle: "", email: "", phone: "", isPrimary: "false" }).success).toBe(false);
  });

  it("enforces ISO country codes for addresses", () => {
    expect(businessPartyAddressSchema.safeParse({ organisationId, partyId: organisationId, addressType: "billing", label: "Head office", line1: "P.O. Box 1", line2: "", city: "Dar es Salaam", region: "", postalCode: "", countryCode: "TZA", isPrimary: "true" }).success).toBe(false);
  });
});
