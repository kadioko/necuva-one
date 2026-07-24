export type MinorUnits = bigint;

export function parseMinorUnits(value: string): MinorUnits {
  if (!/^-?\d+$/.test(value)) {
    throw new Error("Amount must be an integer number of minor units.");
  }

  return BigInt(value);
}

export function formatTzs(value: MinorUnits): string {
  return new Intl.NumberFormat("en-TZ", {
    style: "currency",
    currency: "TZS",
    maximumFractionDigits: 0,
  }).format(Number(value) / 100);
}
