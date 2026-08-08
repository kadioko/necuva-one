"use client";

import { useActionState, type ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { initialMasterDataActionState, upsertBankAccount, upsertMobileMoneyAccount, upsertPaymentMethod } from "../commands";

type Choice = { code?: string; id?: string; label: string };

function Select({ children, id, name, required = false }: { children: ReactNode; id: string; name: string; required?: boolean }) {
  return <select className="h-10 rounded-md border bg-background px-3 text-sm" id={id} name={name} required={required}>{children}</select>;
}

function Message({ message, status }: { message?: string; status: "idle" | "success" | "error" }) {
  return message ? <p className={status === "error" ? "text-sm text-destructive sm:col-span-2" : "text-sm text-muted-foreground sm:col-span-2"}>{message}</p> : null;
}

function CompanyField({ companies, id }: { companies: Choice[]; id: string }) {
  return <label className="grid gap-2"><Label htmlFor={id}>Legal company</Label><Select id={id} name="companyId" required><option value="">Choose a company</option>{companies.map((company) => <option key={company.id} value={company.id}>{company.label}</option>)}</Select></label>;
}

function CurrencyField({ currencies, id }: { currencies: Choice[]; id: string }) {
  return <label className="grid gap-2"><Label htmlFor={id}>Currency</Label><Select id={id} name="currencyCode" required><option value="">Choose a currency</option>{currencies.map((currency) => <option key={currency.code} value={currency.code}>{currency.code} - {currency.label}</option>)}</Select></label>;
}

function StatusFields({ prefix }: { prefix: string }) {
  return <><label className="grid gap-2"><Label htmlFor={`${prefix}Default`}>Default account</Label><Select id={`${prefix}Default`} name="isDefault"><option value="false">No</option><option value="true">Yes</option></Select></label><label className="grid gap-2"><Label htmlFor={`${prefix}Active`}>Status</Label><Select id={`${prefix}Active`} name="isActive"><option value="true">Active</option><option value="false">Inactive</option></Select></label></>;
}

export function PaymentMethodForm({ companies, organisationId }: { companies: Choice[]; organisationId: string }) {
  const [state, action, pending] = useActionState(upsertPaymentMethod, initialMasterDataActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><CompanyField companies={companies} id="paymentMethodCompany" /><label className="grid gap-2"><Label htmlFor="paymentMethodCode">Code</Label><Input id="paymentMethodCode" name="code" required /></label><label className="grid gap-2"><Label htmlFor="paymentMethodName">Name</Label><Input id="paymentMethodName" name="name" required /></label><label className="grid gap-2"><Label htmlFor="paymentMethodKind">Type</Label><Select id="paymentMethodKind" name="kind"><option value="cash">Cash</option><option value="bank_transfer">Bank transfer</option><option value="mobile_money">Mobile money</option><option value="card">Card</option><option value="cheque">Cheque</option><option value="other">Other</option></Select></label><label className="grid gap-2 sm:col-span-2"><Label htmlFor="paymentInstructions">Instructions</Label><Input id="paymentInstructions" name="instructions" /></label><label className="grid gap-2"><Label htmlFor="paymentMethodActive">Status</Label><Select id="paymentMethodActive" name="isActive"><option value="true">Active</option><option value="false">Inactive</option></Select></label><div className="self-end"><Button disabled={pending} type="submit">{pending ? "Saving..." : "Save payment method"}</Button></div><Message message={state.message} status={state.status} /></form>;
}

export function BankAccountForm({ companies, currencies, organisationId }: { companies: Choice[]; currencies: Choice[]; organisationId: string }) {
  const [state, action, pending] = useActionState(upsertBankAccount, initialMasterDataActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><CompanyField companies={companies} id="bankCompany" /><label className="grid gap-2"><Label htmlFor="bankCode">Code</Label><Input id="bankCode" name="code" required /></label><label className="grid gap-2"><Label htmlFor="bankDisplayName">Display name</Label><Input id="bankDisplayName" name="name" required /></label><label className="grid gap-2"><Label htmlFor="bankName">Bank name</Label><Input id="bankName" name="bankName" required /></label><label className="grid gap-2"><Label htmlFor="bankAccountName">Account name</Label><Input id="bankAccountName" name="accountName" required /></label><label className="grid gap-2"><Label htmlFor="bankAccountNumber">Account number</Label><Input autoComplete="off" id="bankAccountNumber" name="accountNumber" required /></label><label className="grid gap-2"><Label htmlFor="bankBranchName">Bank branch</Label><Input id="bankBranchName" name="branchName" /></label><label className="grid gap-2"><Label htmlFor="bankSwift">SWIFT / BIC</Label><Input id="bankSwift" name="swiftCode" /></label><CurrencyField currencies={currencies} id="bankCurrency" /><StatusFields prefix="bank" /><div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Saving..." : "Save bank account"}</Button></div><Message message={state.message} status={state.status} /></form>;
}

export function MobileMoneyAccountForm({ companies, currencies, organisationId }: { companies: Choice[]; currencies: Choice[]; organisationId: string }) {
  const [state, action, pending] = useActionState(upsertMobileMoneyAccount, initialMasterDataActionState);
  return <form action={action} className="grid gap-3 sm:grid-cols-2"><input name="organisationId" type="hidden" value={organisationId} /><CompanyField companies={companies} id="mobileCompany" /><label className="grid gap-2"><Label htmlFor="mobileCode">Code</Label><Input id="mobileCode" name="code" required /></label><label className="grid gap-2"><Label htmlFor="mobileDisplayName">Display name</Label><Input id="mobileDisplayName" name="name" required /></label><label className="grid gap-2"><Label htmlFor="mobileProvider">Provider</Label><Input id="mobileProvider" name="providerName" required /></label><label className="grid gap-2"><Label htmlFor="mobileAccountName">Account name</Label><Input id="mobileAccountName" name="accountName" required /></label><label className="grid gap-2"><Label htmlFor="mobilePhone">Phone number</Label><Input id="mobilePhone" inputMode="tel" name="phoneNumber" placeholder="+255..." required /></label><CurrencyField currencies={currencies} id="mobileCurrency" /><StatusFields prefix="mobile" /><div className="sm:col-span-2"><Button disabled={pending} type="submit">{pending ? "Saving..." : "Save mobile-money account"}</Button></div><Message message={state.message} status={state.status} /></form>;
}
