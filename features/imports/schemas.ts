import { z } from "zod";

import { uuidSchema } from "@/lib/validation/common";

export const stageImportSchema = z.object({
  organisationId: uuidSchema,
  importType: z.enum(["business_parties", "catalog_items"]),
});

export const confirmImportSchema = z.object({ importId: uuidSchema });
