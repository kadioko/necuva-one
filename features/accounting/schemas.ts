import { z } from "zod";

import { uuidSchema } from "@/lib/validation/common";

const accountCodeSchema = z.string().trim().toUpperCase().regex(/^[A-Z0-9.-]{2,30}$/);
const accountTypeSchema = z.enum(["asset", "liability", "equity", "income", "expense"]);

export const accountGroupSchema = z.object({
  organisationId: uuidSchema,
  companyId: uuidSchema,
  parentGroupId: z.preprocess((value) => value === "" ? undefined : value, uuidSchema.optional()),
  code: accountCodeSchema,
  name: z.string().trim().min(1).max(150),
  accountType: accountTypeSchema,
  description: z.preprocess((value) => value === "" ? undefined : value, z.string().trim().max(500).optional()),
});

export const chartAccountSchema = z.object({
  id: z.preprocess((value) => value === "" ? undefined : value, uuidSchema.optional()),
  organisationId: uuidSchema,
  companyId: uuidSchema,
  groupId: uuidSchema,
  code: accountCodeSchema,
  name: z.string().trim().min(1).max(150),
  accountType: accountTypeSchema,
  description: z.preprocess((value) => value === "" ? undefined : value, z.string().trim().max(500).optional()),
  isControlAccount: z.enum(["true", "false"]),
  allowManualPosting: z.enum(["true", "false"]),
  isActive: z.enum(["true", "false"]),
}).refine((value) => value.isControlAccount === "false" || value.allowManualPosting === "false", { path: ["allowManualPosting"], message: "Control accounts cannot allow manual posting." });

export const fiscalYearSchema = z.object({
  organisationId: uuidSchema,
  companyId: uuidSchema,
  name: z.string().trim().min(2).max(100),
  startDate: z.iso.date().refine((value) => value.endsWith("-01"), "Fiscal years must begin on the first day of a month."),
});
