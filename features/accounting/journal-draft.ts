import { parseDecimalToMinorUnits } from "@/lib/money/minor-units";

import { draftJournalSchema } from "./schemas";

export type DraftJournalCommand = {
  organisationId: string;
  companyId: string;
  branchId: string;
  journalDate: string;
  description: string;
  sourceReference: string;
  lines: Array<{
    accountId: string;
    description?: string;
    debitMinor: string;
    creditMinor: string;
  }>;
};

export function prepareDraftJournalCommand(input: unknown, decimalPlaces: number): DraftJournalCommand {
  const parsed = draftJournalSchema.parse(input);
  let debitTotal = 0n;
  let creditTotal = 0n;

  const lines = parsed.lines.map((line, index) => {
    const debitMinor = parseDecimalToMinorUnits(line.debit || "0", decimalPlaces);
    const creditMinor = parseDecimalToMinorUnits(line.credit || "0", decimalPlaces);

    if (!((debitMinor > 0n && creditMinor === 0n) || (creditMinor > 0n && debitMinor === 0n))) {
      throw new Error(`Line ${index + 1} must contain exactly one positive amount.`);
    }

    debitTotal += debitMinor;
    creditTotal += creditMinor;

    return {
      accountId: line.accountId,
      ...(line.description ? { description: line.description } : {}),
      debitMinor: debitMinor.toString(),
      creditMinor: creditMinor.toString(),
    };
  });

  if (debitTotal !== creditTotal) {
    throw new Error("Draft journal debits and credits must balance.");
  }

  return {
    organisationId: parsed.organisationId,
    companyId: parsed.companyId,
    branchId: parsed.branchId,
    journalDate: parsed.journalDate,
    description: parsed.description,
    sourceReference: parsed.sourceReference,
    lines,
  };
}
