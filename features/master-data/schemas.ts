import { z } from "zod";

import { uuidSchema } from "@/lib/validation/common";

const decimalSchema = z.string().regex(/^\d+(\.\d{1,10})?$/);

export const currencySchema = z.object({
  code: z.string().trim().toUpperCase().regex(/^[A-Z]{3}$/),
  name: z.string().trim().min(1).max(100),
  symbol: z.string().trim().min(1).max(12),
  decimalPlaces: z.coerce.number().int().min(0).max(4),
  isActive: z.enum(["true", "false"]),
});

export const exchangeRateSchema = z.object({
  organisationId: uuidSchema,
  currencyCode: z.string().trim().toUpperCase().regex(/^[A-Z]{3}$/),
  effectiveOn: z.iso.date(),
  rate: decimalSchema.refine((value) => Number(value) > 0),
  sourceReference: z.string().trim().min(3).max(500),
});

export const taxConfigurationSchema = z.object({
  organisationId: uuidSchema,
  code: z.string().trim().toUpperCase().regex(/^[A-Z0-9_.-]{2,50}$/),
  name: z.string().trim().min(1).max(150),
  taxType: z.enum(["vat", "withholding", "other"]),
  ratePercent: decimalSchema.refine((value) => Number(value) >= 0 && Number(value) <= 100),
  effectiveFrom: z.iso.date(),
  effectiveTo: z.preprocess((value) => value === "" ? undefined : value, z.iso.date().optional()),
  sourceReference: z.string().trim().min(3).max(500),
}).refine((value) => !value.effectiveTo || value.effectiveTo >= value.effectiveFrom, { path: ["effectiveTo"], message: "End date must not precede the start date." });

export const configurationApprovalSchema = z.object({ id: uuidSchema });
