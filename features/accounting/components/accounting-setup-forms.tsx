"use client";

import { useActionState, useMemo, useState, type ChangeEventHandler, type ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { createAccountGroup, createFiscalYear, initialAccountingActionState, upsertChartAccount } from "../commands";

type CompanyChoice = { id: string; name: string };
type GroupChoice = { accountType: string; code: string; companyId: string; id: string; name: string };

function Select({ children, id, name, onChange, required = false, value }: { children: ReactNode; id: string; name: string; onChange?: ChangeEventHandler<HTMLSelectElement>; required?: boolean; value?: string }) {
  return <select className="h-10 rounded-md border bg-background px-3 text-sm" id={id} name={name} onChange={onChange} required={required} value={value}>{children}</select>;
}

function CompanyField({ companies, id, onChange, value }: { companies: CompanyChoice[]; id: string; onChange?: ChangeEventHandler<HTMLSelectElement>; value?: string }) {
  return <label className="grid gap-2"><Label htmlFor={id}>Legal company</Label><Select id={id} name="companyId" onChange={onChange} required value={value}><option value="">Choose a company</option>{companies.map((company) => <option key={company.id} value={company.id}>{company.name}</option>)}</Select></label>;
}

function AccountTypeField({ id, onChange, value }: { id: string; onChange?: ChangeEventHandler<HTMLSelectElement>; value?: string }) {
  return <label className="grid gap-2"><Label htmlFor={id}>Account type</Label><Select id={id} name="accountType" onChange={onChange} value={value}><option value="asset">Asset</option><option value="liability">Liability</option><option value="equity">Equity</option><option value="income">Income</option><option value="expense">Expense</option></Select></label>;
}

function Message({ message, status }: { message?: string; status: "idle" | "success" | "error" }) {
  return message ? <p className={status === "error" ? "text-sm text-destructive sm:col-span-2" : "text-sm text-muted-foreground sm:col-span-2"}>{message}</p> : null;
}

export function AccountGroupForm({ companies, defaultCompanyId, groups, organisationId }: { companies: CompanyChoice[]; defaultCompanyId: string; groups: GroupChoice[]; organisationId: string }) {
  const [companyId, setCompanyId] = useState(defaultCompanyId);
  const [accountType, setAccountType] = useState("asset");
  const parents = useMemo(() => groups.filter((group) => group.companyId === companyId && group.accountType === accountType), [accountType, companyId, groups]);
  const [state, action, pending] = useActionState(createAccountGroup, initialAccountingActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><CompanyField companies={companies} id="groupCompany" onChange={(event) => setCompanyId(event.target.value)} value={companyId} /><AccountTypeField id="groupType" onChange={(event) => setAccountType(event.target.value)} value={accountType} /><label className="grid gap-2"><Label htmlFor="groupCode">Code</Label><Input id="groupCode" name="code" required /></label><label className="grid gap-2"><Label htmlFor="groupName">Name</Label><Input id="groupName" name="name" required /></label><label className="grid gap-2 sm:col-span-2"><Label htmlFor="parentGroup">Parent group</Label><Select id="parentGroup" name="parentGroupId"><option value="">None</option>{parents.map((group) => <option key={group.id} value={group.id}>{group.code} - {group.name}</option>)}</Select></label><label className="grid gap-2 sm:col-span-2"><Label htmlFor="groupDescription">Description</Label><Input id="groupDescription" name="description" /></label><div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Creating..." : "Create account group"}</Button></div><Message message={state.message} status={state.status} /></form>;
}

export function ChartAccountForm({ companies, defaultCompanyId, groups, organisationId }: { companies: CompanyChoice[]; defaultCompanyId: string; groups: GroupChoice[]; organisationId: string }) {
  const [companyId, setCompanyId] = useState(defaultCompanyId);
  const [accountType, setAccountType] = useState("asset");
  const [isControlAccount, setIsControlAccount] = useState("false");
  const [manualPosting, setManualPosting] = useState("true");
  const availableGroups = useMemo(() => groups.filter((group) => group.companyId === companyId && group.accountType === accountType), [accountType, companyId, groups]);
  const [state, action, pending] = useActionState(upsertChartAccount, initialAccountingActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><CompanyField companies={companies} id="accountCompany" onChange={(event) => setCompanyId(event.target.value)} value={companyId} /><AccountTypeField id="accountType" onChange={(event) => setAccountType(event.target.value)} value={accountType} /><label className="grid gap-2 sm:col-span-2"><Label htmlFor="accountGroup">Account group</Label><Select id="accountGroup" name="groupId" required><option value="">Choose a matching group</option>{availableGroups.map((group) => <option key={group.id} value={group.id}>{group.code} - {group.name}</option>)}</Select></label><label className="grid gap-2"><Label htmlFor="accountCode">Account code</Label><Input id="accountCode" name="code" required /></label><label className="grid gap-2"><Label htmlFor="accountName">Account name</Label><Input id="accountName" name="name" required /></label><label className="grid gap-2 sm:col-span-2"><Label htmlFor="accountDescription">Description</Label><Input id="accountDescription" name="description" /></label><label className="grid gap-2"><Label htmlFor="controlAccount">Control account</Label><Select id="controlAccount" name="isControlAccount" onChange={(event) => { setIsControlAccount(event.target.value); if (event.target.value === "true") setManualPosting("false"); }} value={isControlAccount}><option value="false">No</option><option value="true">Yes</option></Select></label><label className="grid gap-2"><Label htmlFor="manualPosting">Manual posting</Label><Select id="manualPosting" name="allowManualPosting" onChange={(event) => setManualPosting(event.target.value)} value={manualPosting}><option disabled={isControlAccount === "true"} value="true">Allowed</option><option value="false">Blocked</option></Select></label><label className="grid gap-2"><Label htmlFor="accountActive">Status</Label><Select id="accountActive" name="isActive"><option value="true">Active</option><option value="false">Inactive</option></Select></label><div className="self-end"><Button disabled={pending} type="submit">{pending ? "Saving..." : "Save chart account"}</Button></div><Message message={state.message} status={state.status} /></form>;
}

export function FiscalYearForm({ companies, defaultCompanyId, organisationId }: { companies: CompanyChoice[]; defaultCompanyId: string; organisationId: string }) {
  const [companyId, setCompanyId] = useState(defaultCompanyId);
  const [state, action, pending] = useActionState(createFiscalYear, initialAccountingActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><CompanyField companies={companies} id="fiscalCompany" onChange={(event) => setCompanyId(event.target.value)} value={companyId} /><label className="grid gap-2"><Label htmlFor="fiscalName">Fiscal year name</Label><Input id="fiscalName" name="name" placeholder="2026/2027" required /></label><label className="grid gap-2"><Label htmlFor="fiscalStart">Starts on</Label><Input id="fiscalStart" name="startDate" required type="date" /></label><div className="self-end"><Button disabled={pending} type="submit">{pending ? "Creating..." : "Create draft calendar"}</Button></div><Message message={state.message} status={state.status} /></form>;
}
