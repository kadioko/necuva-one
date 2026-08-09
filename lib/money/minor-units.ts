export type MinorUnits = bigint;

export function parseMinorUnits(value: string): MinorUnits {
  if (!/^-?\d+$/.test(value)) {
    throw new Error("Amount must be an integer number of minor units.");
  }

  return BigInt(value);
}

export function parseDecimalToMinorUnits(value: string, decimalPlaces: number): MinorUnits {
  if (!Number.isInteger(decimalPlaces) || decimalPlaces < 0 || decimalPlaces > 4) {
    throw new Error("Currency decimal places must be an integer from 0 to 4.");
  }

  const normalized = value.trim();
  const match = /^(\d+)(?:\.(\d+))?$/.exec(normalized);
  if (!match) {
    throw new Error("Amount must be a non-negative decimal number.");
  }

  const fraction = match[2] ?? "";
  if (fraction.length > decimalPlaces) {
    throw new Error(`Amount may have at most ${decimalPlaces} decimal places.`);
  }

  const scale = 10n ** BigInt(decimalPlaces);
  const paddedFraction = fraction.padEnd(decimalPlaces, "0");
  return BigInt(match[1]) * scale + BigInt(paddedFraction || "0");
}

export function formatMinorUnits(value: MinorUnits, decimalPlaces: number): string {
  if (!Number.isInteger(decimalPlaces) || decimalPlaces < 0 || decimalPlaces > 4) {
    throw new Error("Currency decimal places must be an integer from 0 to 4.");
  }

  if (decimalPlaces === 0) return value.toString();
  const scale = 10n ** BigInt(decimalPlaces);
  const whole = value / scale;
  const fraction = (value % scale).toString().padStart(decimalPlaces, "0");
  return `${whole}.${fraction}`;
}

export function formatTzs(value: MinorUnits): string {
  return new Intl.NumberFormat("en-TZ", {
    style: "currency",
    currency: "TZS",
    maximumFractionDigits: 0,
  }).format(Number(value) / 100);
}
