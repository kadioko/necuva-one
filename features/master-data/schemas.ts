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

const partyTypeSchema = z.enum(["customer", "supplier", "both"]);

export const businessPartyCategorySchema = z.object({
  organisationId: uuidSchema,
  partyType: partyTypeSchema,
  name: z.string().trim().min(1).max(100),
});

export const businessPartySchema = z.object({
  id: z.preprocess((value) => value === "" ? undefined : value, uuidSchema.optional()),
  organisationId: uuidSchema,
  categoryId: z.preprocess((value) => value === "" ? undefined : value, uuidSchema.optional()),
  partyType: partyTypeSchema,
  externalCode: z.preprocess((value) => value === "" ? undefined : value, z.string().trim().toUpperCase().regex(/^[A-Z0-9_.-]{2,50}$/).optional()),
  displayName: z.string().trim().min(1).max(200),
  legalName: z.preprocess((value) => value === "" ? undefined : value, z.string().trim().min(1).max(250).optional()),
  taxIdentificationNumber: z.preprocess((value) => value === "" ? undefined : value, z.string().trim().max(100).optional()),
  email: z.preprocess((value) => value === "" ? undefined : value, z.email().transform((value) => value.toLowerCase()).optional()),
  phone: z.preprocess((value) => value === "" ? undefined : value, z.string().trim().max(50).optional()),
  isActive: z.enum(["true", "false"]),
});

export const businessPartyContactSchema = z.object({
  organisationId: uuidSchema,
  partyId: uuidSchema,
  fullName: z.string().trim().min(1).max(200),
  jobTitle: z.preprocess((value) => value === "" ? undefined : value, z.string().trim().max(150).optional()),
  email: z.preprocess((value) => value === "" ? undefined : value, z.email().transform((value) => value.toLowerCase()).optional()),
  phone: z.preprocess((value) => value === "" ? undefined : value, z.string().trim().max(50).optional()),
  isPrimary: z.enum(["true", "false"]),
}).refine((value) => Boolean(value.email || value.phone), { message: "An email address or phone number is required." });

export const businessPartyAddressSchema = z.object({
  organisationId: uuidSchema,
  partyId: uuidSchema,
  addressType: z.enum(["physical", "billing", "delivery", "postal"]),
  label: z.string().trim().min(1).max(100),
  line1: z.string().trim().min(1).max(200),
  line2: z.preprocess((value) => value === "" ? undefined : value, z.string().trim().max(200).optional()),
  city: z.preprocess((value) => value === "" ? undefined : value, z.string().trim().max(100).optional()),
  region: z.preprocess((value) => value === "" ? undefined : value, z.string().trim().max(100).optional()),
  postalCode: z.preprocess((value) => value === "" ? undefined : value, z.string().trim().max(30).optional()),
  countryCode: z.string().trim().toUpperCase().regex(/^[A-Z]{2}$/),
  isPrimary: z.enum(["true", "false"]),
});
