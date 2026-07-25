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
  scope: z.enum(["organisation", "company", "branch"]),
  scopeId: z.preprocess((value) => value === "" ? undefined : value, uuidSchema.optional()),
}).superRefine((value, context) => {
  if (value.scope !== "organisation" && !value.scopeId) context.addIssue({ code: "custom", path: ["scopeId"], message: "A scope ID is required." });
  if (value.roleCode === "company.admin" && value.scope !== "company") context.addIssue({ code: "custom", path: ["scope"], message: "Company administrators require a company scope." });
});

export const supportAccessSchema = z.object({ organisationId: uuidSchema, supportUserId: uuidSchema, reason: z.string().trim().min(10).max(1000), expiresAt: z.string().trim().min(1) });
export const organisationStatusSchema = z.object({ organisationId: uuidSchema, status: z.enum(["trial", "active", "grace_period", "suspended", "closed"]), reason: z.string().trim().min(10).max(1000) });
export const subscriptionPlanSchema = z.object({ code: z.string().trim().toLowerCase().regex(/^[a-z0-9_.-]{3,100}$/), name: z.string().trim().min(1).max(150), monthlyPriceMinor: z.string().regex(/^\d+$/), isActive: z.enum(["true", "false"]) });
export const subscriptionAssignmentSchema = z.object({ organisationId: uuidSchema, planCode: z.string().trim().toLowerCase().regex(/^[a-z0-9_.-]{3,100}$/) });
export const implementationStageSchema = z.object({ organisationId: uuidSchema, stage: z.enum(["lead", "qualified", "discovery", "proposal", "contract_signed", "tenant_provisioned", "data_collection", "configuration", "initial_migration", "user_testing", "training", "final_migration", "go_live", "hypercare", "active_support"]) });
