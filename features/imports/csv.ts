import { parse } from "csv-parse/sync";

export type MasterDataImportType = "business_parties" | "catalog_items";
export type ParsedImportRow = { rowNumber: number; data: Record<string, string> };

const definitions = {
  business_parties: {
    headers: ["external_code", "display_name", "party_type", "legal_name", "tax_identification_number", "email", "phone", "is_active"],
    fields: ["externalCode", "displayName", "partyType", "legalName", "taxIdentificationNumber", "email", "phone", "isActive"],
  },
  catalog_items: {
    headers: ["code", "name", "item_type", "base_unit_code", "category_code", "description", "tracks_inventory", "is_active"],
    fields: ["code", "name", "itemType", "baseUnitCode", "categoryCode", "description", "tracksInventory", "isActive"],
  },
} as const;

export class ImportCsvError extends Error {}

export function importTemplate(type: MasterDataImportType) {
  return `${definitions[type].headers.join(",")}\r\n`;
}

export function parseMasterDataCsv(type: MasterDataImportType, source: string): ParsedImportRow[] {
  const definition = definitions[type];
  let parsed: Array<{ info: { lines: number }; record: Record<string, string> }>;
  try {
    parsed = parse(source, {
      bom: true,
      columns(headers: string[]) {
        if (headers.length !== definition.headers.length || headers.some((header, index) => header !== definition.headers[index])) {
          throw new ImportCsvError(`CSV columns must exactly match: ${definition.headers.join(", ")}.`);
        }
        return headers;
      },
      info: true,
      max_record_size: 100_000,
      skip_empty_lines: true,
      trim: true,
    });
  } catch (error) {
    if (error instanceof ImportCsvError) throw error;
    throw new ImportCsvError("The CSV file is malformed or has inconsistent columns.");
  }
  return parsed.map(({ info, record }) => ({
    rowNumber: info.lines,
    data: Object.fromEntries(definition.headers.map((header, index) => [definition.fields[index], record[header] ?? ""])),
  }));
}
