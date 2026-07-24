import { z } from "zod";

export const uuidSchema = z.string().uuid();

export const organisationNameSchema = z
  .string()
  .trim()
  .min(1, "Enter an organisation name.")
  .max(250, "Organisation names may not exceed 250 characters.");

export const supportAccessRequestSchema = z
  .object({
    organisationId: uuidSchema,
    reason: z.string().trim().min(10).max(1000),
    startsAt: z.coerce.date(),
    expiresAt: z.coerce.date(),
  })
  .refine((value) => value.expiresAt > value.startsAt, {
    message: "Support access must expire after it starts.",
    path: ["expiresAt"],
  });
