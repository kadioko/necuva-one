"use client";

import { useActionState, useMemo, useRef, useState } from "react";
import { Plus, Save, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createDraftJournal, initialAccountingActionState } from "@/features/accounting/commands";
import { formatMinorUnits, parseDecimalToMinorUnits } from "@/lib/money/minor-units";

export type JournalCompanyChoice = { currencyCode: string; decimalPlaces: number; id: string; name: string };
export type JournalBranchChoice = { code: string; companyId: string; id: string; name: string };
export type JournalAccountChoice = { code: string; companyId: string; id: string; name: string };
export type JournalPeriodChoice = { companyId: string; endDate: string; id: string; name: string; startDate: string; status: string };

type DraftLine = { accountId: string; credit: string; debit: string; description: string; key: number };

const initialLines: DraftLine[] = [
  { accountId: "", credit: "", debit: "", description: "", key: 1 },
  { accountId: "", credit: "", debit: "", description: "", key: 2 },
];

function SelectField({ children, id, label, name, onChange, value }: { children: React.ReactNode; id: string; label: string; name: string; onChange: (value: string) => void; value: string }) {
  return <label className="grid min-w-0 gap-2"><Label htmlFor={id}>{label}</Label><select className="h-10 min-w-0 rounded-md border bg-background px-3 text-sm" id={id} name={name} onChange={(event) => onChange(event.target.value)} required value={value}>{children}</select></label>;
}

export function DraftJournalForm({ accounts, branches, companies, defaultBranchId, defaultCompanyId, organisationId, periods }: { accounts: JournalAccountChoice[]; branches: JournalBranchChoice[]; companies: JournalCompanyChoice[]; defaultBranchId: string; defaultCompanyId: string; organisationId: string; periods: JournalPeriodChoice[] }) {
  const [companyId, setCompanyId] = useState(defaultCompanyId);
  const company = companies.find((choice) => choice.id === companyId);
  const companyBranches = useMemo(() => branches.filter((branch) => branch.companyId === companyId), [branches, companyId]);
  const companyAccounts = useMemo(() => accounts.filter((account) => account.companyId === companyId), [accounts, companyId]);
  const companyPeriods = useMemo(() => periods.filter((period) => period.companyId === companyId), [companyId, periods]);
  const initialBranch = companyBranches.some((branch) => branch.id === defaultBranchId) ? defaultBranchId : companyBranches[0]?.id ?? "";
  const [branchId, setBranchId] = useState(initialBranch);
  const [lines, setLines] = useState(initialLines);
  const nextLineKey = useRef(3);
  const [state, action, pending] = useActionState(createDraftJournal, initialAccountingActionState);

  const totals = useMemo(() => {
    if (!company) return null;
    try {
      return lines.reduce((total, line) => ({
        debit: total.debit + parseDecimalToMinorUnits(line.debit || "0", company.decimalPlaces),
        credit: total.credit + parseDecimalToMinorUnits(line.credit || "0", company.decimalPlaces),
      }), { debit: 0n, credit: 0n });
    } catch {
      return null;
    }
  }, [company, lines]);

  const changeCompany = (nextCompanyId: string) => {
    setCompanyId(nextCompanyId);
    setBranchId(branches.find((branch) => branch.companyId === nextCompanyId)?.id ?? "");
    setLines((current) => current.map((line) => ({ ...line, accountId: "" })));
  };

  const updateLine = (key: number, field: keyof Omit<DraftLine, "key">, value: string) => {
    setLines((current) => current.map((line) => line.key === key ? { ...line, [field]: value } : line));
  };

  const addLine = () => {
    setLines((current) => [...current, { accountId: "", credit: "", debit: "", description: "", key: nextLineKey.current++ }]);
  };

  const removeLine = (key: number) => {
    setLines((current) => current.length > 2 ? current.filter((line) => line.key !== key) : current);
  };

  const serializedLines = JSON.stringify(lines.map(({ accountId, credit, debit, description }) => ({ accountId, credit, debit, description })));
  const amountStep = company?.decimalPlaces ? `0.${"0".repeat(company.decimalPlaces - 1)}1` : "1";

  return <form action={action} className="space-y-6">
    <input name="organisationId" type="hidden" value={organisationId} />
    <input name="lines" type="hidden" value={serializedLines} />
    <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      <SelectField id="journalCompany" label="Legal company" name="companyId" onChange={changeCompany} value={companyId}><option value="">Choose a company</option>{companies.map((choice) => <option key={choice.id} value={choice.id}>{choice.name}</option>)}</SelectField>
      <SelectField id="journalBranch" label="Branch" name="branchId" onChange={setBranchId} value={branchId}><option value="">Choose a branch</option>{companyBranches.map((branch) => <option key={branch.id} value={branch.id}>{branch.code} - {branch.name}</option>)}</SelectField>
      <label className="grid gap-2"><Label htmlFor="journalDate">Journal date</Label><Input id="journalDate" name="journalDate" required type="date" /></label>
      <label className="grid gap-2"><Label htmlFor="sourceReference">Source reference</Label><Input id="sourceReference" maxLength={150} name="sourceReference" placeholder="PV-1042" required /></label>
    </div>
    <label className="grid gap-2"><Label htmlFor="journalDescription">Description</Label><Input id="journalDescription" maxLength={500} name="description" required /></label>

    <div className="overflow-x-auto border">
      <table className="w-full min-w-[820px] table-fixed text-left text-sm">
        <thead className="bg-muted text-muted-foreground"><tr><th className="w-12 p-3">#</th><th className="w-[30%] p-3">Account</th><th className="p-3">Line description</th><th className="w-36 p-3 text-right">Debit</th><th className="w-36 p-3 text-right">Credit</th><th className="w-12 p-3"><span className="sr-only">Actions</span></th></tr></thead>
        <tbody>{lines.map((line, index) => <tr className="border-t" key={line.key}><td className="p-3 align-middle text-muted-foreground">{index + 1}</td><td className="p-2"><select aria-label={`Line ${index + 1} account`} className="h-9 w-full rounded-md border bg-background px-2 text-sm" onChange={(event) => updateLine(line.key, "accountId", event.target.value)} required value={line.accountId}><option value="">Choose an account</option>{companyAccounts.map((account) => <option key={account.id} value={account.id}>{account.code} - {account.name}</option>)}</select></td><td className="p-2"><Input aria-label={`Line ${index + 1} description`} maxLength={250} onChange={(event) => updateLine(line.key, "description", event.target.value)} value={line.description} /></td><td className="p-2"><Input aria-label={`Line ${index + 1} debit`} className="text-right tabular-nums" inputMode="decimal" min="0" onChange={(event) => updateLine(line.key, "debit", event.target.value)} step={amountStep} value={line.debit} /></td><td className="p-2"><Input aria-label={`Line ${index + 1} credit`} className="text-right tabular-nums" inputMode="decimal" min="0" onChange={(event) => updateLine(line.key, "credit", event.target.value)} step={amountStep} value={line.credit} /></td><td className="p-2"><Button aria-label={`Remove line ${index + 1}`} disabled={lines.length <= 2} onClick={() => removeLine(line.key)} size="icon" title="Remove line" type="button" variant="ghost"><Trash2 /></Button></td></tr>)}</tbody>
        <tfoot className="border-t bg-muted/40 font-medium"><tr><td className="p-3" colSpan={3}>Totals {company ? `(${company.currencyCode})` : ""}</td><td className="p-3 text-right tabular-nums">{totals && company ? formatMinorUnits(totals.debit, company.decimalPlaces) : "-"}</td><td className="p-3 text-right tabular-nums">{totals && company ? formatMinorUnits(totals.credit, company.decimalPlaces) : "-"}</td><td /></tr></tfoot>
      </table>
    </div>

    <div className="flex flex-wrap items-center justify-between gap-3">
      <Button onClick={addLine} type="button" variant="outline"><Plus />Add line</Button>
      <div className="flex items-center gap-3"><span className="text-xs text-muted-foreground">{companyPeriods.length ? `${companyPeriods[0].startDate} to ${companyPeriods.at(-1)?.endDate}` : "No fiscal periods available"}</span><Button disabled={pending || !company || !branchId || !companyAccounts.length || !companyPeriods.length} type="submit"><Save />{pending ? "Creating..." : "Create draft"}</Button></div>
    </div>
    {state.message ? <p aria-live="polite" className={state.status === "error" ? "text-sm text-destructive" : "text-sm text-muted-foreground"}>{state.message}</p> : null}
  </form>;
}
