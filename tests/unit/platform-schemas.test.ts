import { describe, expect, it } from "vitest";

import { provisionOrganisationSchema } from "@/features/platform/schemas";

const validInput = {
  organisationLegalName: "Necuva Customer Limited",
  organisationDisplayName: "Necuva Customer",
  companyLegalName: "Necuva Customer Limited",
  branchCode: "hq",
  branchName: "Head Office",
  ownerUserId: "10000000-0000-4000-8000-000000000001",
};

describe("provisionOrganisationSchema", () => {
  it("normalises a branch code before the provisioning command", () => {
    expect(provisionOrganisationSchema.parse(validInput).branchCode).toBe("HQ");
  });

  it("rejects invalid branch codes and owner IDs", () => {
    expect(
      provisionOrganisationSchema.safeParse({ ...validInput, branchCode: "head office", ownerUserId: "not-a-uuid" }).success,
    ).toBe(false);
  });
});
