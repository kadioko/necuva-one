import { z } from "zod";

import { organisationNameSchema, uuidSchema } from "@/lib/validation/common";

export const provisionOrganisationSchema = z.object({
  organisationLegalName: organisationNameSchema,
  organisationDisplayName: organisationNameSchema,
  companyLegalName: organisationNameSchema,
  branchCode: z.string().trim().toUpperCase().regex(/^[A-Z0-9_-]{2,30}$/),
  branchName: z.string().trim().min(1).max(150),
  ownerUserId: uuidSchema,
});

export type ProvisionOrganisationInput = z.infer<typeof provisionOrganisationSchema>;

export const organisationStructureSchema = z.object({
  organisationId: uuidSchema,
  entityType: z.enum(["company", "branch", "department", "warehouse"]),
  name: z.string().trim().min(1).max(250),
  code: z.string().trim().toUpperCase().max(30).optional(),
  companyId: z.preprocess((value) => value === "" ? undefined : value, uuidSchema.optional()),
  branchId: z.preprocess((value) => value === "" ? undefined : value, uuidSchema.optional()),
}).superRefine((value, context) => {
  if (["branch", "department", "warehouse"].includes(value.entityType) && !value.companyId) {
    context.addIssue({ code: "custom", path: ["companyId"], message: "A company is required." });
  }
  if (value.entityType === "warehouse" && !value.branchId) {
    context.addIssue({ code: "custom", path: ["branchId"], message: "A branch is required." });
  }
});

export const organisationMembershipSchema = z.object({
  organisationId: uuidSchema,
  userId: uuidSchema,
  roleCode: z.enum(["organisation.owner", "company.admin", "read.only"]),
  status: z.enum(["active", "inactive"]),
});
