import { describe, expect, it } from "vitest";

import { membershipInvitationSchema, organisationMembershipSchema, organisationStatusSchema, provisionOrganisationSchema, subscriptionPlanSchema } from "@/features/platform/schemas";

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

  it("requires non-organisation scopes to include a scope ID", () => {
    expect(organisationMembershipSchema.safeParse({ organisationId: validInput.ownerUserId, userId: validInput.ownerUserId, roleCode: "company.admin", status: "active", scope: "company", scopeId: "" }).success).toBe(false);
  });

  it("normalises invitation email addresses and enforces the selected scope", () => {
    const invitation = membershipInvitationSchema.parse({ organisationId: validInput.ownerUserId, email: "ADMIN@NECUVA.TEST", roleCode: "company.admin", scope: "company", scopeId: validInput.ownerUserId });
    expect(invitation.email).toBe("admin@necuva.test");
    expect(membershipInvitationSchema.safeParse({ ...invitation, scope: "warehouse", scopeId: "" }).success).toBe(false);
  });

  it("accepts lifecycle reasons and integer subscription prices", () => {
    expect(organisationStatusSchema.safeParse({ organisationId: validInput.ownerUserId, status: "suspended", reason: "Payment terms are overdue." }).success).toBe(true);
    expect(subscriptionPlanSchema.safeParse({ code: "growth", name: "Growth", monthlyPriceMinor: "60000000", isActive: "true" }).success).toBe(true);
  });
});
