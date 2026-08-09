import { Badge } from "@/components/ui/badge";
import { DraftJournalForm, type JournalAccountChoice, type JournalBranchChoice, type JournalCompanyChoice, type JournalPeriodChoice } from "@/features/accounting/components/draft-journal-form";
import { formatMinorUnits } from "@/lib/money/minor-units";
import { createClient } from "@/lib/supabase/server";

type JournalDraft = { branch_code: string; branch_id: string; company_id: string; currency_code: string; description: string; id: string; journal_date: string; journal_number: string; source_reference: string; status: "draft"; total_minor: string };
type JournalBranch = { code: string; company_id: string; id: string; name: string };

export default async function JournalPreparationPage() {
  const supabase = await createClient();
  const { data: context } = await supabase.from("user_tenant_contexts").select("organisation_id, company_id, branch_id").maybeSingle();
  const organisationId = context?.organisation_id;

  if (!organisationId) return <section className="space-y-4"><div><p className="text-sm font-medium text-muted-foreground">Accounting</p><h1 className="mt-1 text-2xl font-semibold">Journal preparation</h1></div><p className="text-sm text-muted-foreground">Choose a workspace from the overview before preparing journals.</p></section>;

  const [branchResult, companyResult, accountResult, periodResult, journalResult, currencyResult] = await Promise.all([
    supabase.rpc("list_journal_preparation_branches", { target_organisation_id: organisationId }),
    supabase.from("companies").select("id, legal_name, currency_code").eq("organisation_id", organisationId).eq("is_active", true).order("legal_name"),
    supabase.from("chart_accounts").select("id, company_id, code, name").eq("organisation_id", organisationId).eq("is_active", true).eq("allow_manual_posting", true).eq("is_control_account", false).order("code").limit(1000),
    supabase.from("fiscal_periods").select("id, company_id, name, start_date, end_date, status").eq("organisation_id", organisationId).in("status", ["future", "open"]).order("start_date").limit(600),
    supabase.rpc("list_journal_drafts", { target_organisation_id: organisationId }),
    supabase.from("currencies").select("code, decimal_places").eq("is_active", true),
  ]);

  const branches = (branchResult.data ?? []) as JournalBranch[];
  const authorizedCompanyIds = new Set(branches.map((branch) => branch.company_id));
  const decimals = new Map((currencyResult.data ?? []).map((currency) => [currency.code, currency.decimal_places]));
  const companies: JournalCompanyChoice[] = (companyResult.data ?? []).filter((company) => authorizedCompanyIds.has(company.id)).map((company) => ({ currencyCode: company.currency_code, decimalPlaces: decimals.get(company.currency_code) ?? 2, id: company.id, name: company.legal_name }));
  const branchChoices: JournalBranchChoice[] = branches.map((branch) => ({ code: branch.code, companyId: branch.company_id, id: branch.id, name: branch.name }));
  const accounts: JournalAccountChoice[] = (accountResult.data ?? []).map((account) => ({ code: account.code, companyId: account.company_id, id: account.id, name: account.name }));
  const periods: JournalPeriodChoice[] = (periodResult.data ?? []).map((period) => ({ companyId: period.company_id, endDate: period.end_date, id: period.id, name: period.name, startDate: period.start_date, status: period.status }));
  const requestedCompanyId = context.company_id && authorizedCompanyIds.has(context.company_id) ? context.company_id : companies[0]?.id ?? "";
  const defaultBranchId = context.branch_id && branches.some((branch) => branch.id === context.branch_id && branch.company_id === requestedCompanyId) ? context.branch_id : branches.find((branch) => branch.company_id === requestedCompanyId)?.id ?? "";
  const companyNames = new Map(companies.map((company) => [company.id, company.name]));
  const companyDecimals = new Map(companies.map((company) => [company.id, company.decimalPlaces]));
  const journals = (journalResult.data ?? []) as JournalDraft[];

  return <section className="max-w-7xl space-y-8">
    <div><p className="text-sm font-medium text-muted-foreground">Accounting</p><h1 className="mt-1 text-2xl font-semibold">Journal preparation</h1><p className="mt-2 text-sm leading-6 text-muted-foreground">Prepare balanced base-currency entries for review. Drafts do not affect the ledger.</p></div>
    {companies.length ? <DraftJournalForm accounts={accounts} branches={branchChoices} companies={companies} defaultBranchId={defaultBranchId} defaultCompanyId={requestedCompanyId} organisationId={organisationId} periods={periods} /> : <p className="border-t pt-6 text-sm text-muted-foreground">No branch is available with journal-preparation permission.</p>}
    <section className="space-y-4 border-t pt-6"><div className="flex items-center justify-between gap-3"><h2 className="text-lg font-semibold">Recent drafts</h2><span className="text-sm text-muted-foreground">Up to 100</span></div><div className="overflow-x-auto border"><table className="w-full min-w-[820px] text-left text-sm"><thead className="bg-muted text-muted-foreground"><tr><th className="p-3">Journal</th><th className="p-3">Date</th><th className="p-3">Description</th><th className="p-3">Source</th><th className="p-3">Branch</th><th className="p-3 text-right">Total</th><th className="p-3">Status</th></tr></thead><tbody>{journals.length ? journals.map((journal) => <tr className="border-t" key={journal.id}><td className="p-3"><span className="font-mono text-xs">{journal.journal_number}</span><span className="block text-xs text-muted-foreground">{companyNames.get(journal.company_id) ?? "-"}</span></td><td className="p-3 tabular-nums">{journal.journal_date}</td><td className="max-w-xs p-3">{journal.description}</td><td className="p-3 font-mono text-xs">{journal.source_reference}</td><td className="p-3">{journal.branch_code}</td><td className="p-3 text-right tabular-nums">{journal.currency_code} {formatMinorUnits(BigInt(journal.total_minor), companyDecimals.get(journal.company_id) ?? 2)}</td><td className="p-3"><Badge variant="secondary">{journal.status}</Badge></td></tr>) : <tr><td className="p-3 text-muted-foreground" colSpan={7}>No authorized journal drafts found.</td></tr>}</tbody></table></div></section>
  </section>;
}
