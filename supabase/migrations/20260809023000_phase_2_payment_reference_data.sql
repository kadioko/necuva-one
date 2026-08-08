create type public.payment_method_kind as enum ('cash', 'bank_transfer', 'mobile_money', 'card', 'cheque', 'other');

create table public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  company_id uuid not null,
  code text not null check (code ~ '^[A-Z0-9_.-]{2,50}$'),
  name text not null check (char_length(trim(name)) between 1 and 100),
  kind public.payment_method_kind not null,
  instructions text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (company_id, organisation_id) references public.companies(id, organisation_id) on delete restrict,
  unique (organisation_id, company_id, code),
  unique (id, organisation_id, company_id)
);

create table public.bank_accounts (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  company_id uuid not null,
  code text not null check (code ~ '^[A-Z0-9_.-]{2,50}$'),
  name text not null check (char_length(trim(name)) between 1 and 100),
  bank_name text not null check (char_length(trim(bank_name)) between 2 and 150),
  account_name text not null check (char_length(trim(account_name)) between 2 and 200),
  account_number text not null check (char_length(trim(account_number)) between 4 and 64),
  branch_name text,
  swift_code text check (swift_code is null or swift_code ~ '^[A-Z0-9]{8}([A-Z0-9]{3})?$'),
  currency_code char(3) not null references public.currencies(code) on delete restrict,
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (company_id, organisation_id) references public.companies(id, organisation_id) on delete restrict,
  unique (organisation_id, company_id, code),
  unique (organisation_id, bank_name, account_number),
  unique (id, organisation_id, company_id)
);
create unique index bank_accounts_default_currency_idx on public.bank_accounts (company_id, currency_code) where is_default and is_active;

create table public.mobile_money_accounts (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  company_id uuid not null,
  code text not null check (code ~ '^[A-Z0-9_.-]{2,50}$'),
  name text not null check (char_length(trim(name)) between 1 and 100),
  provider_name text not null check (char_length(trim(provider_name)) between 2 and 100),
  account_name text not null check (char_length(trim(account_name)) between 2 and 200),
  phone_number text not null check (phone_number ~ '^\+?[0-9]{7,20}$'),
  currency_code char(3) not null references public.currencies(code) on delete restrict,
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (company_id, organisation_id) references public.companies(id, organisation_id) on delete restrict,
  unique (organisation_id, company_id, code),
  unique (organisation_id, provider_name, phone_number),
  unique (id, organisation_id, company_id)
);
create unique index mobile_money_accounts_default_currency_idx on public.mobile_money_accounts (company_id, currency_code) where is_default and is_active;

create trigger payment_methods_set_updated_at before update on public.payment_methods for each row execute function private.set_updated_at();
create trigger bank_accounts_set_updated_at before update on public.bank_accounts for each row execute function private.set_updated_at();
create trigger mobile_money_accounts_set_updated_at before update on public.mobile_money_accounts for each row execute function private.set_updated_at();

insert into public.permissions (code, module_code, description) values
  ('organisation.payment_references.manage', 'platform', 'Manage company payment methods and settlement account references')
on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code = 'organisation.payment_references.manage'
where r.organisation_id is null and r.code = 'organisation.owner' on conflict do nothing;

create or replace function private.has_company_permission(target_organisation_id uuid, target_company_id uuid, permission_code text)
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
  select exists (
    select 1
    from public.organisation_memberships m
    join public.membership_roles mr on mr.membership_id = m.id
    join public.role_permissions rp on rp.role_id = mr.role_id
    join public.permissions p on p.id = rp.permission_id
    join public.membership_scopes ms on ms.membership_id = m.id
    where m.organisation_id = target_organisation_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and p.code = permission_code
      and (
        ms.scope = 'organisation'
        or (ms.scope = 'company' and ms.scope_id = target_company_id)
        or (ms.scope = 'branch' and exists (select 1 from public.branches b where b.id = ms.scope_id and b.organisation_id = target_organisation_id and b.company_id = target_company_id))
        or (ms.scope = 'warehouse' and exists (select 1 from public.warehouses w where w.id = ms.scope_id and w.organisation_id = target_organisation_id and w.company_id = target_company_id))
      )
  );
$$;
revoke all on function private.has_company_permission(uuid, uuid, text) from public;

alter table public.payment_methods enable row level security;
alter table public.payment_methods force row level security;
alter table public.bank_accounts enable row level security;
alter table public.bank_accounts force row level security;
alter table public.mobile_money_accounts enable row level security;
alter table public.mobile_money_accounts force row level security;
grant select on public.payment_methods, public.bank_accounts, public.mobile_money_accounts to authenticated;
create policy payment_methods_authorised_select on public.payment_methods for select using (private.has_company_permission(organisation_id, company_id, 'organisation.payment_references.manage'));
create policy bank_accounts_authorised_select on public.bank_accounts for select using (private.has_company_permission(organisation_id, company_id, 'organisation.payment_references.manage'));
create policy mobile_money_accounts_authorised_select on public.mobile_money_accounts for select using (private.has_company_permission(organisation_id, company_id, 'organisation.payment_references.manage'));

create or replace function public.upsert_payment_method(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; target_company_id uuid := (input ->> 'companyId')::uuid; target_id uuid := nullif(input ->> 'id', '')::uuid; method_code text := upper(nullif(trim(input ->> 'code'), '')); method_name text := nullif(trim(input ->> 'name'), ''); method_kind public.payment_method_kind := (input ->> 'kind')::public.payment_method_kind; method_instructions text := nullif(trim(input ->> 'instructions'), ''); active boolean := coalesce((input ->> 'isActive')::boolean, true); result_id uuid;
begin
  if not private.has_company_permission(org_id, target_company_id, 'organisation.payment_references.manage') then raise exception 'Company payment-reference management permission is required' using errcode='42501'; end if;
  if method_code is null or method_code !~ '^[A-Z0-9_.-]{2,50}$' or method_name is null or method_kind is null or not exists (select 1 from public.companies where id=target_company_id and organisation_id=org_id and is_active) then raise exception 'Payment method input is invalid' using errcode='22023'; end if;
  if target_id is null then
    insert into public.payment_methods (organisation_id, company_id, code, name, kind, instructions, is_active) values (org_id, target_company_id, method_code, method_name, method_kind, method_instructions, active) returning id into result_id;
  else
    update public.payment_methods set code=method_code, name=method_name, kind=method_kind, instructions=method_instructions, is_active=active where id=target_id and organisation_id=org_id and company_id=target_company_id returning id into result_id;
    if result_id is null then raise exception 'Payment method does not exist' using errcode='23503'; end if;
  end if;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), case when target_id is null then 'payment_method_created' else 'payment_method_updated' end, 'payment_method', result_id, jsonb_build_object('companyId', target_company_id, 'code', method_code, 'name', method_name, 'kind', method_kind, 'isActive', active));
  return result_id;
end; $$;

create or replace function public.upsert_bank_account(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; target_company_id uuid := (input ->> 'companyId')::uuid; target_id uuid := nullif(input ->> 'id', '')::uuid; account_code text := upper(nullif(trim(input ->> 'code'), '')); display_name text := nullif(trim(input ->> 'name'), ''); institution text := nullif(trim(input ->> 'bankName'), ''); holder_name text := nullif(trim(input ->> 'accountName'), ''); number_value text := nullif(trim(input ->> 'accountNumber'), ''); bank_branch text := nullif(trim(input ->> 'branchName'), ''); bank_swift text := upper(nullif(trim(input ->> 'swiftCode'), '')); target_currency char(3) := upper(nullif(trim(input ->> 'currencyCode'), '')); default_account boolean := coalesce((input ->> 'isDefault')::boolean, false); active boolean := coalesce((input ->> 'isActive')::boolean, true); result_id uuid;
begin
  if not private.has_company_permission(org_id, target_company_id, 'organisation.payment_references.manage') then raise exception 'Company payment-reference management permission is required' using errcode='42501'; end if;
  if account_code is null or account_code !~ '^[A-Z0-9_.-]{2,50}$' or display_name is null or institution is null or holder_name is null or number_value is null or char_length(number_value) not between 4 and 64 or (bank_swift is not null and bank_swift !~ '^[A-Z0-9]{8}([A-Z0-9]{3})?$') or (default_account and not active) or not exists (select 1 from public.companies where id=target_company_id and organisation_id=org_id and is_active) or not exists (select 1 from public.currencies where code=target_currency and is_active) then raise exception 'Bank account input is invalid' using errcode='22023'; end if;
  if default_account and active then update public.bank_accounts set is_default=false where company_id=target_company_id and currency_code=target_currency and is_default and (target_id is null or id<>target_id); end if;
  if target_id is null then
    insert into public.bank_accounts (organisation_id, company_id, code, name, bank_name, account_name, account_number, branch_name, swift_code, currency_code, is_default, is_active) values (org_id, target_company_id, account_code, display_name, institution, holder_name, number_value, bank_branch, bank_swift, target_currency, default_account, active) returning id into result_id;
  else
    update public.bank_accounts set code=account_code, name=display_name, bank_name=institution, account_name=holder_name, account_number=number_value, branch_name=bank_branch, swift_code=bank_swift, currency_code=target_currency, is_default=default_account, is_active=active where id=target_id and organisation_id=org_id and company_id=target_company_id returning id into result_id;
    if result_id is null then raise exception 'Bank account does not exist' using errcode='23503'; end if;
  end if;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), case when target_id is null then 'bank_account_created' else 'bank_account_updated' end, 'bank_account', result_id, jsonb_build_object('companyId', target_company_id, 'code', account_code, 'name', display_name, 'bankName', institution, 'accountNumberLast4', right(number_value, 4), 'currencyCode', target_currency, 'isDefault', default_account, 'isActive', active));
  return result_id;
end; $$;

create or replace function public.upsert_mobile_money_account(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; target_company_id uuid := (input ->> 'companyId')::uuid; target_id uuid := nullif(input ->> 'id', '')::uuid; account_code text := upper(nullif(trim(input ->> 'code'), '')); display_name text := nullif(trim(input ->> 'name'), ''); provider text := nullif(trim(input ->> 'providerName'), ''); holder_name text := nullif(trim(input ->> 'accountName'), ''); phone text := nullif(trim(input ->> 'phoneNumber'), ''); target_currency char(3) := upper(nullif(trim(input ->> 'currencyCode'), '')); default_account boolean := coalesce((input ->> 'isDefault')::boolean, false); active boolean := coalesce((input ->> 'isActive')::boolean, true); result_id uuid;
begin
  if not private.has_company_permission(org_id, target_company_id, 'organisation.payment_references.manage') then raise exception 'Company payment-reference management permission is required' using errcode='42501'; end if;
  if account_code is null or account_code !~ '^[A-Z0-9_.-]{2,50}$' or display_name is null or provider is null or holder_name is null or phone is null or phone !~ '^\+?[0-9]{7,20}$' or (default_account and not active) or not exists (select 1 from public.companies where id=target_company_id and organisation_id=org_id and is_active) or not exists (select 1 from public.currencies where code=target_currency and is_active) then raise exception 'Mobile-money account input is invalid' using errcode='22023'; end if;
  if default_account and active then update public.mobile_money_accounts set is_default=false where company_id=target_company_id and currency_code=target_currency and is_default and (target_id is null or id<>target_id); end if;
  if target_id is null then
    insert into public.mobile_money_accounts (organisation_id, company_id, code, name, provider_name, account_name, phone_number, currency_code, is_default, is_active) values (org_id, target_company_id, account_code, display_name, provider, holder_name, phone, target_currency, default_account, active) returning id into result_id;
  else
    update public.mobile_money_accounts set code=account_code, name=display_name, provider_name=provider, account_name=holder_name, phone_number=phone, currency_code=target_currency, is_default=default_account, is_active=active where id=target_id and organisation_id=org_id and company_id=target_company_id returning id into result_id;
    if result_id is null then raise exception 'Mobile-money account does not exist' using errcode='23503'; end if;
  end if;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), case when target_id is null then 'mobile_money_account_created' else 'mobile_money_account_updated' end, 'mobile_money_account', result_id, jsonb_build_object('companyId', target_company_id, 'code', account_code, 'name', display_name, 'providerName', provider, 'phoneNumberLast4', right(phone, 4), 'currencyCode', target_currency, 'isDefault', default_account, 'isActive', active));
  return result_id;
end; $$;

create or replace function public.create_custom_role(input jsonb) returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; role_code text := lower(nullif(trim(input ->> 'code'), '')); role_name text := nullif(trim(input ->> 'name'), ''); role_scope public.scope_type := (input ->> 'defaultScope')::public.scope_type; permission_codes text[] := array(select jsonb_array_elements_text(coalesce(input -> 'permissionCodes','[]'::jsonb))); role_id uuid;
begin
 if not private.has_organisation_permission(org_id,'organisation.roles.manage') then raise exception 'Organisation role management permission is required' using errcode='42501'; end if;
 if role_code is null or role_code !~ '^[a-z0-9_.-]{3,100}$' or role_name is null or role_scope not in ('organisation','company','branch','warehouse') or cardinality(permission_codes)=0 then raise exception 'Custom role input is invalid' using errcode='22023'; end if;
 if exists (select 1 from public.roles where organisation_id is null and code=role_code) then raise exception 'Custom role code conflicts with a system role' using errcode='23505'; end if;
 if exists (select 1 from unnest(permission_codes) code where code not in ('organisation.structure.manage','organisation.memberships.manage','organisation.audit.read','organisation.support_access.manage','organisation.localisation.manage','organisation.localisation.approve','organisation.parties.manage','organisation.catalog.manage','organisation.payment_references.manage')) then raise exception 'Custom role contains unsupported permission' using errcode='22023'; end if;
 insert into public.roles (organisation_id,code,name,default_scope,is_system) values (org_id,role_code,role_name,role_scope,false) returning id into role_id;
 insert into public.role_permissions (role_id,permission_id) select role_id,id from public.permissions where code=any(permission_codes);
 insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (org_id,auth.uid(),'custom_role_created','role',role_id,input); return role_id;
end; $$;

revoke all on function public.upsert_payment_method(jsonb), public.upsert_bank_account(jsonb), public.upsert_mobile_money_account(jsonb) from public;
grant execute on function public.upsert_payment_method(jsonb), public.upsert_bank_account(jsonb), public.upsert_mobile_money_account(jsonb) to authenticated;
