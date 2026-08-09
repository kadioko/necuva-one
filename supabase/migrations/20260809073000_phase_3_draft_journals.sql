create type public.accounting_journal_status as enum ('draft', 'submitted', 'approved', 'posted', 'reversed');

create or replace function private.has_branch_permission(
  target_organisation_id uuid,
  target_company_id uuid,
  target_branch_id uuid,
  permission_code text
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.organisation_memberships membership
    join public.membership_roles membership_role on membership_role.membership_id = membership.id
    join public.role_permissions role_permission on role_permission.role_id = membership_role.role_id
    join public.permissions permission on permission.id = role_permission.permission_id
    join public.membership_scopes membership_scope on membership_scope.membership_id = membership.id
    where membership.organisation_id = target_organisation_id
      and membership.user_id = auth.uid()
      and membership.status = 'active'
      and permission.code = permission_code
      and exists (
        select 1
        from public.branches target_branch
        where target_branch.id = target_branch_id
          and target_branch.organisation_id = target_organisation_id
          and target_branch.company_id = target_company_id
      )
      and (
        membership_scope.scope = 'organisation'
        or (membership_scope.scope = 'company' and membership_scope.scope_id = target_company_id)
        or (membership_scope.scope = 'branch' and membership_scope.scope_id = target_branch_id)
        or (
          membership_scope.scope = 'warehouse'
          and exists (
            select 1
            from public.warehouses warehouse
            where warehouse.id = membership_scope.scope_id
              and warehouse.organisation_id = target_organisation_id
              and warehouse.company_id = target_company_id
              and warehouse.branch_id = target_branch_id
          )
        )
      )
  );
$$;
revoke all on function private.has_branch_permission(uuid, uuid, uuid, text) from public;

alter table public.fiscal_periods
  add constraint fiscal_periods_id_year_tenant_company_key
  unique (id, fiscal_year_id, organisation_id, company_id);

create table public.accounting_journal_sequences (
  organisation_id uuid not null,
  company_id uuid not null,
  fiscal_year_id uuid not null,
  prefix text not null check (prefix ~ '^[A-Z0-9]{2,10}$'),
  next_number bigint not null default 1 check (next_number > 0),
  foreign key (fiscal_year_id, organisation_id, company_id)
    references public.fiscal_years(id, organisation_id, company_id) on delete restrict,
  primary key (organisation_id, company_id, fiscal_year_id, prefix)
);

create table public.accounting_journals (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  company_id uuid not null,
  branch_id uuid not null,
  fiscal_year_id uuid not null,
  fiscal_period_id uuid not null,
  journal_number text not null check (journal_number ~ '^[A-Z0-9]+-[0-9]{4}-[0-9]{6,}$'),
  journal_date date not null,
  description text not null check (char_length(trim(description)) between 1 and 500),
  source_reference text not null check (char_length(trim(source_reference)) between 1 and 150),
  currency_code char(3) not null references public.currencies(code) on delete restrict,
  status public.accounting_journal_status not null default 'draft',
  total_debit_minor bigint not null check (total_debit_minor > 0),
  total_credit_minor bigint not null check (total_credit_minor > 0),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (branch_id, organisation_id, company_id)
    references public.branches(id, organisation_id, company_id) on delete restrict,
  foreign key (fiscal_year_id, organisation_id, company_id)
    references public.fiscal_years(id, organisation_id, company_id) on delete restrict,
  foreign key (fiscal_period_id, fiscal_year_id, organisation_id, company_id)
    references public.fiscal_periods(id, fiscal_year_id, organisation_id, company_id) on delete restrict,
  check (total_debit_minor = total_credit_minor),
  unique (organisation_id, company_id, journal_number),
  unique (id, organisation_id, company_id, branch_id)
);
create index accounting_journals_branch_date_idx
  on public.accounting_journals (branch_id, journal_date desc, journal_number desc);
create index accounting_journals_company_period_idx
  on public.accounting_journals (company_id, fiscal_period_id, status);

create table public.accounting_journal_lines (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  company_id uuid not null,
  branch_id uuid not null,
  journal_id uuid not null,
  line_number smallint not null check (line_number between 1 and 200),
  account_id uuid not null,
  description text check (description is null or char_length(trim(description)) between 1 and 250),
  debit_minor bigint not null default 0 check (debit_minor >= 0),
  credit_minor bigint not null default 0 check (credit_minor >= 0),
  created_at timestamptz not null default now(),
  foreign key (journal_id, organisation_id, company_id, branch_id)
    references public.accounting_journals(id, organisation_id, company_id, branch_id) on delete restrict,
  foreign key (account_id, organisation_id, company_id)
    references public.chart_accounts(id, organisation_id, company_id) on delete restrict,
  check ((debit_minor > 0 and credit_minor = 0) or (credit_minor > 0 and debit_minor = 0)),
  unique (journal_id, line_number)
);
create index accounting_journal_lines_account_idx
  on public.accounting_journal_lines (account_id, journal_id);

create trigger accounting_journals_set_updated_at
before update on public.accounting_journals
for each row execute function private.set_updated_at();

insert into public.permissions (code, module_code, description) values
  ('organisation.accounting.journals.prepare', 'accounting', 'Prepare balanced manual journal drafts')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select role.id, permission.id
from public.roles role
join public.permissions permission on permission.code = 'organisation.accounting.journals.prepare'
where role.organisation_id is null and role.code = 'organisation.owner'
on conflict do nothing;

alter table public.accounting_journal_sequences enable row level security;
alter table public.accounting_journal_sequences force row level security;
alter table public.accounting_journals enable row level security;
alter table public.accounting_journals force row level security;
alter table public.accounting_journal_lines enable row level security;
alter table public.accounting_journal_lines force row level security;

grant select on public.accounting_journals, public.accounting_journal_lines to authenticated;

create policy accounting_journals_authorised_select on public.accounting_journals
  for select using (
    private.has_branch_permission(
      organisation_id,
      company_id,
      branch_id,
      'organisation.accounting.journals.prepare'
    )
  );
create policy accounting_journal_lines_authorised_select on public.accounting_journal_lines
  for select using (
    private.has_branch_permission(
      organisation_id,
      company_id,
      branch_id,
      'organisation.accounting.journals.prepare'
    )
  );
create policy chart_accounts_journal_preparer_select on public.chart_accounts
  for select using (
    private.has_company_permission(
      organisation_id,
      company_id,
      'organisation.accounting.journals.prepare'
    )
  );
create policy fiscal_years_journal_preparer_select on public.fiscal_years
  for select using (
    private.has_company_permission(
      organisation_id,
      company_id,
      'organisation.accounting.journals.prepare'
    )
  );
create policy fiscal_periods_journal_preparer_select on public.fiscal_periods
  for select using (
    private.has_company_permission(
      organisation_id,
      company_id,
      'organisation.accounting.journals.prepare'
    )
  );

create or replace function public.list_journal_preparation_branches(target_organisation_id uuid)
returns table (id uuid, company_id uuid, code text, name text)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select branch.id, branch.company_id, branch.code, branch.name
  from public.branches branch
  where branch.organisation_id = target_organisation_id
    and branch.is_active
    and private.has_branch_permission(
      branch.organisation_id,
      branch.company_id,
      branch.id,
      'organisation.accounting.journals.prepare'
    )
  order by branch.code;
$$;

create or replace function public.create_draft_journal(input jsonb)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  org_id uuid;
  target_company_id uuid;
  target_branch_id uuid;
  target_date date;
  journal_description text := nullif(trim(input ->> 'description'), '');
  source text := nullif(trim(input ->> 'sourceReference'), '');
  lines jsonb := input -> 'lines';
  line jsonb;
  line_index integer := 0;
  target_account_id uuid;
  line_description text;
  debit_amount bigint;
  credit_amount bigint;
  debit_total bigint := 0;
  credit_total bigint := 0;
  target_currency_code char(3);
  target_fiscal_year_id uuid;
  target_fiscal_period_id uuid;
  fiscal_year_start date;
  allocated_number bigint;
  allocated_journal_number text;
  result_id uuid;
begin
  begin
    org_id := (input ->> 'organisationId')::uuid;
    target_company_id := (input ->> 'companyId')::uuid;
    target_branch_id := (input ->> 'branchId')::uuid;
    target_date := (input ->> 'journalDate')::date;
  exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow then
    raise exception 'Draft journal input is invalid' using errcode = '22023';
  end;

  if not private.has_branch_permission(
    org_id,
    target_company_id,
    target_branch_id,
    'organisation.accounting.journals.prepare'
  ) then
    raise exception 'Branch journal preparation permission is required' using errcode = '42501';
  end if;

  select company.currency_code
  into target_currency_code
  from public.companies company
  join public.currencies currency on currency.code = company.currency_code and currency.is_active
  where company.id = target_company_id
    and company.organisation_id = org_id
    and company.is_active;

  if target_currency_code is null
    or not exists (
      select 1
      from public.branches branch
      where branch.id = target_branch_id
        and branch.organisation_id = org_id
        and branch.company_id = target_company_id
        and branch.is_active
    )
    or target_date is null
    or journal_description is null
    or char_length(journal_description) > 500
    or source is null
    or char_length(source) > 150
    or coalesce(jsonb_typeof(lines), 'null') <> 'array'
  then
    raise exception 'Draft journal input is invalid' using errcode = '22023';
  end if;

  if jsonb_array_length(lines) not between 2 and 200 then
    raise exception 'Draft journal input is invalid' using errcode = '22023';
  end if;

  select period.id, period.fiscal_year_id, fiscal_year.start_date
  into target_fiscal_period_id, target_fiscal_year_id, fiscal_year_start
  from public.fiscal_periods period
  join public.fiscal_years fiscal_year
    on fiscal_year.id = period.fiscal_year_id
    and fiscal_year.organisation_id = period.organisation_id
    and fiscal_year.company_id = period.company_id
  where period.organisation_id = org_id
    and period.company_id = target_company_id
    and target_date between period.start_date and period.end_date
    and period.status in ('future', 'open')
    and fiscal_year.status in ('draft', 'open');

  if target_fiscal_period_id is null then
    raise exception 'Journal date is outside an available fiscal period' using errcode = '22023';
  end if;

  for line in select value from jsonb_array_elements(lines)
  loop
    line_index := line_index + 1;
    line_description := nullif(trim(line ->> 'description'), '');

    if coalesce(line ->> 'debitMinor', '') !~ '^\d+$'
      or coalesce(line ->> 'creditMinor', '') !~ '^\d+$'
      or char_length(coalesce(line_description, '')) > 250
    then
      raise exception 'Journal line % is invalid', line_index using errcode = '22023';
    end if;

    begin
      target_account_id := (line ->> 'accountId')::uuid;
      debit_amount := (line ->> 'debitMinor')::bigint;
      credit_amount := (line ->> 'creditMinor')::bigint;
    exception when invalid_text_representation or numeric_value_out_of_range then
      raise exception 'Journal line % is invalid', line_index using errcode = '22023';
    end;

    if not ((debit_amount > 0 and credit_amount = 0) or (credit_amount > 0 and debit_amount = 0)) then
      raise exception 'Journal line % must contain exactly one positive amount', line_index using errcode = '22023';
    end if;

    if not exists (
      select 1
      from public.chart_accounts account
      where account.id = target_account_id
        and account.organisation_id = org_id
        and account.company_id = target_company_id
        and account.is_active
        and account.allow_manual_posting
        and not account.is_control_account
    ) then
      raise exception 'Journal line % account is unavailable for manual posting', line_index using errcode = '22023';
    end if;

    begin
      debit_total := debit_total + debit_amount;
      credit_total := credit_total + credit_amount;
    exception when numeric_value_out_of_range then
      raise exception 'Journal totals exceed the supported amount range' using errcode = '22003';
    end;
  end loop;

  if debit_total <= 0 or debit_total <> credit_total then
    raise exception 'Draft journal debits and credits must balance' using errcode = '23514';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(target_company_id::text || target_fiscal_year_id::text || 'GJ', 0));
  insert into public.accounting_journal_sequences (
    organisation_id,
    company_id,
    fiscal_year_id,
    prefix,
    next_number
  ) values (
    org_id,
    target_company_id,
    target_fiscal_year_id,
    'GJ',
    2
  )
  on conflict (organisation_id, company_id, fiscal_year_id, prefix)
  do update set next_number = public.accounting_journal_sequences.next_number + 1
  returning next_number - 1 into allocated_number;

  allocated_journal_number := 'GJ-' || to_char(fiscal_year_start, 'YYYY') || '-' || lpad(allocated_number::text, 6, '0');

  insert into public.accounting_journals (
    organisation_id,
    company_id,
    branch_id,
    fiscal_year_id,
    fiscal_period_id,
    journal_number,
    journal_date,
    description,
    source_reference,
    currency_code,
    total_debit_minor,
    total_credit_minor,
    created_by
  ) values (
    org_id,
    target_company_id,
    target_branch_id,
    target_fiscal_year_id,
    target_fiscal_period_id,
    allocated_journal_number,
    target_date,
    journal_description,
    source,
    target_currency_code,
    debit_total,
    credit_total,
    auth.uid()
  ) returning id into result_id;

  line_index := 0;
  for line in select value from jsonb_array_elements(lines)
  loop
    line_index := line_index + 1;
    insert into public.accounting_journal_lines (
      organisation_id,
      company_id,
      branch_id,
      journal_id,
      line_number,
      account_id,
      description,
      debit_minor,
      credit_minor
    ) values (
      org_id,
      target_company_id,
      target_branch_id,
      result_id,
      line_index,
      (line ->> 'accountId')::uuid,
      nullif(trim(line ->> 'description'), ''),
      (line ->> 'debitMinor')::bigint,
      (line ->> 'creditMinor')::bigint
    );
  end loop;

  insert into public.audit_events (
    organisation_id,
    actor_user_id,
    action,
    entity_type,
    entity_id,
    after_state
  ) values (
    org_id,
    auth.uid(),
    'draft_journal_created',
    'accounting_journal',
    result_id,
    jsonb_build_object(
      'companyId', target_company_id,
      'branchId', target_branch_id,
      'fiscalYearId', target_fiscal_year_id,
      'fiscalPeriodId', target_fiscal_period_id,
      'journalNumber', allocated_journal_number,
      'journalDate', target_date,
      'sourceReference', source,
      'currencyCode', target_currency_code,
      'lineCount', line_index,
      'totalDebitMinor', debit_total,
      'totalCreditMinor', credit_total,
      'status', 'draft'
    )
  );

  return result_id;
end;
$$;

create or replace function public.list_journal_drafts(target_organisation_id uuid)
returns table (
  id uuid,
  company_id uuid,
  branch_id uuid,
  branch_code text,
  journal_number text,
  journal_date date,
  description text,
  source_reference text,
  currency_code text,
  total_minor text,
  status public.accounting_journal_status
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select
    journal.id,
    journal.company_id,
    journal.branch_id,
    branch.code,
    journal.journal_number,
    journal.journal_date,
    journal.description,
    journal.source_reference,
    journal.currency_code::text,
    journal.total_debit_minor::text,
    journal.status
  from public.accounting_journals journal
  join public.branches branch on branch.id = journal.branch_id
  where journal.organisation_id = target_organisation_id
    and journal.status = 'draft'
    and private.has_branch_permission(
      journal.organisation_id,
      journal.company_id,
      journal.branch_id,
      'organisation.accounting.journals.prepare'
    )
  order by journal.journal_date desc, journal.journal_number desc
  limit 100;
$$;

create or replace function public.create_custom_role(input jsonb)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  org_id uuid := (input ->> 'organisationId')::uuid;
  role_code text := lower(nullif(trim(input ->> 'code'), ''));
  role_name text := nullif(trim(input ->> 'name'), '');
  role_scope public.scope_type := (input ->> 'defaultScope')::public.scope_type;
  permission_codes text[] := array(select jsonb_array_elements_text(coalesce(input -> 'permissionCodes', '[]'::jsonb)));
  role_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.roles.manage') then
    raise exception 'Organisation role management permission is required' using errcode = '42501';
  end if;
  if role_code is null or role_code !~ '^[a-z0-9_.-]{3,100}$' or role_name is null or role_scope not in ('organisation', 'company', 'branch', 'warehouse') or cardinality(permission_codes) = 0 then
    raise exception 'Custom role input is invalid' using errcode = '22023';
  end if;
  if exists (select 1 from public.roles where organisation_id is null and code = role_code) then
    raise exception 'Custom role code conflicts with a system role' using errcode = '23505';
  end if;
  if exists (
    select 1
    from unnest(permission_codes) code
    where code not in (
      'organisation.structure.manage',
      'organisation.memberships.manage',
      'organisation.audit.read',
      'organisation.support_access.manage',
      'organisation.localisation.manage',
      'organisation.localisation.approve',
      'organisation.parties.manage',
      'organisation.catalog.manage',
      'organisation.payment_references.manage',
      'organisation.imports.manage',
      'organisation.accounting.configure',
      'organisation.accounting.journals.prepare'
    )
  ) then
    raise exception 'Custom role contains unsupported permission' using errcode = '22023';
  end if;
  insert into public.roles (organisation_id, code, name, default_scope, is_system)
  values (org_id, role_code, role_name, role_scope, false)
  returning id into role_id;
  insert into public.role_permissions (role_id, permission_id)
  select role_id, id from public.permissions where code = any(permission_codes);
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state)
  values (org_id, auth.uid(), 'custom_role_created', 'role', role_id, input);
  return role_id;
end;
$$;

revoke all on function public.list_journal_preparation_branches(uuid), public.create_draft_journal(jsonb), public.list_journal_drafts(uuid) from public;
grant execute on function public.list_journal_preparation_branches(uuid), public.create_draft_journal(jsonb), public.list_journal_drafts(uuid) to authenticated;
