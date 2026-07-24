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
