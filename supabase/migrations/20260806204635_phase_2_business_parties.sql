create type public.business_party_type as enum ('customer', 'supplier', 'both');
create type public.party_address_type as enum ('physical', 'billing', 'delivery', 'postal');

create table public.business_party_categories (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  party_type public.business_party_type not null,
  name text not null check (char_length(trim(name)) between 1 and 100),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organisation_id, party_type, name),
  unique (id, organisation_id)
);

create table public.business_parties (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  category_id uuid,
  party_type public.business_party_type not null,
  external_code text check (external_code is null or external_code ~ '^[A-Z0-9_.-]{2,50}$'),
  display_name text not null check (char_length(trim(display_name)) between 1 and 200),
  legal_name text check (legal_name is null or char_length(trim(legal_name)) between 1 and 250),
  tax_identification_number text,
  email text check (email is null or email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  phone text,
  is_active boolean not null default true,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (category_id, organisation_id) references public.business_party_categories(id, organisation_id) on delete restrict,
  unique (id, organisation_id)
);
create unique index business_parties_external_code_idx on public.business_parties (organisation_id, external_code) where external_code is not null;
create index business_parties_organisation_type_idx on public.business_parties (organisation_id, party_type, display_name);

create table public.business_party_contacts (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  party_id uuid not null,
  full_name text not null check (char_length(trim(full_name)) between 1 and 200),
  job_title text,
  email text check (email is null or email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  phone text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (email is not null or phone is not null),
  foreign key (party_id, organisation_id) references public.business_parties(id, organisation_id) on delete cascade
);
create unique index business_party_contacts_primary_idx on public.business_party_contacts (party_id) where is_primary;
create index business_party_contacts_party_idx on public.business_party_contacts (organisation_id, party_id);

create table public.business_party_addresses (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null,
  party_id uuid not null,
  address_type public.party_address_type not null,
  label text not null check (char_length(trim(label)) between 1 and 100),
  line_1 text not null check (char_length(trim(line_1)) between 1 and 200),
  line_2 text,
  city text,
  region text,
  postal_code text,
  country_code char(2) not null default 'TZ' check (country_code ~ '^[A-Z]{2}$'),
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (party_id, organisation_id) references public.business_parties(id, organisation_id) on delete cascade
);
create unique index business_party_addresses_primary_idx on public.business_party_addresses (party_id, address_type) where is_primary;
create index business_party_addresses_party_idx on public.business_party_addresses (organisation_id, party_id);

create trigger business_party_categories_set_updated_at before update on public.business_party_categories for each row execute function private.set_updated_at();
create trigger business_parties_set_updated_at before update on public.business_parties for each row execute function private.set_updated_at();
create trigger business_party_contacts_set_updated_at before update on public.business_party_contacts for each row execute function private.set_updated_at();
create trigger business_party_addresses_set_updated_at before update on public.business_party_addresses for each row execute function private.set_updated_at();

alter table public.business_party_categories enable row level security;
alter table public.business_party_categories force row level security;
alter table public.business_parties enable row level security;
alter table public.business_parties force row level security;
alter table public.business_party_contacts enable row level security;
alter table public.business_party_contacts force row level security;
alter table public.business_party_addresses enable row level security;
alter table public.business_party_addresses force row level security;
grant select on public.business_party_categories, public.business_parties, public.business_party_contacts, public.business_party_addresses to authenticated;
create policy business_party_categories_member_select on public.business_party_categories for select using (private.is_active_organisation_member(organisation_id));
create policy business_parties_member_select on public.business_parties for select using (private.is_active_organisation_member(organisation_id));
create policy business_party_contacts_member_select on public.business_party_contacts for select using (private.is_active_organisation_member(organisation_id));
create policy business_party_addresses_member_select on public.business_party_addresses for select using (private.is_active_organisation_member(organisation_id));

insert into public.permissions (code, module_code, description)
values ('organisation.parties.manage', 'platform', 'Manage organisation customer and supplier master data')
on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code = 'organisation.parties.manage'
where r.organisation_id is null and r.code = 'organisation.owner' on conflict do nothing;

create or replace function public.create_business_party_category(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; category_type public.business_party_type := (input ->> 'partyType')::public.business_party_type; category_name text := nullif(trim(input ->> 'name'), ''); result_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.parties.manage') then raise exception 'Organisation party management permission is required' using errcode='42501'; end if;
  if category_type is null or category_name is null then raise exception 'Party category input is invalid' using errcode='22023'; end if;
  insert into public.business_party_categories (organisation_id, party_type, name) values (org_id, category_type, category_name) returning id into result_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'business_party_category_created', 'business_party_category', result_id, input);
  return result_id;
end; $$;

create or replace function public.upsert_business_party(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; target_party_id uuid := nullif(input ->> 'id', '')::uuid; target_category_id uuid := nullif(input ->> 'categoryId', '')::uuid; target_type public.business_party_type := (input ->> 'partyType')::public.business_party_type; target_code text := upper(nullif(trim(input ->> 'externalCode'), '')); target_display_name text := nullif(trim(input ->> 'displayName'), ''); target_legal_name text := nullif(trim(input ->> 'legalName'), ''); target_tin text := nullif(trim(input ->> 'taxIdentificationNumber'), ''); target_email text := lower(nullif(trim(input ->> 'email'), '')); target_phone text := nullif(trim(input ->> 'phone'), ''); target_active boolean := coalesce((input ->> 'isActive')::boolean, true); before_state jsonb; result_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.parties.manage') then raise exception 'Organisation party management permission is required' using errcode='42501'; end if;
  if target_type is null or target_display_name is null or (target_code is not null and target_code !~ '^[A-Z0-9_.-]{2,50}$') or (target_email is not null and target_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') then raise exception 'Business party input is invalid' using errcode='22023'; end if;
  if target_category_id is not null and not exists (select 1 from public.business_party_categories where id=target_category_id and organisation_id=org_id and is_active and party_type in (target_type, 'both')) then raise exception 'Party category is invalid' using errcode='23503'; end if;
  if target_party_id is null then
    insert into public.business_parties (organisation_id, category_id, party_type, external_code, display_name, legal_name, tax_identification_number, email, phone, is_active, created_by) values (org_id, target_category_id, target_type, target_code, target_display_name, target_legal_name, target_tin, target_email, target_phone, target_active, auth.uid()) returning id into result_id;
    insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'business_party_created', 'business_party', result_id, input);
  else
    select to_jsonb(p) into before_state from public.business_parties p where p.id=target_party_id and p.organisation_id=org_id for update;
    if before_state is null then raise exception 'Business party does not exist' using errcode='23503'; end if;
    update public.business_parties set category_id=target_category_id, party_type=target_type, external_code=target_code, display_name=target_display_name, legal_name=target_legal_name, tax_identification_number=target_tin, email=target_email, phone=target_phone, is_active=target_active where id=target_party_id returning id into result_id;
    insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, before_state, after_state) values (org_id, auth.uid(), 'business_party_updated', 'business_party', result_id, before_state, input);
  end if;
  return result_id;
end; $$;

create or replace function public.add_business_party_contact(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; target_party_id uuid := (input ->> 'partyId')::uuid; contact_name text := nullif(trim(input ->> 'fullName'), ''); contact_title text := nullif(trim(input ->> 'jobTitle'), ''); contact_email text := lower(nullif(trim(input ->> 'email'), '')); contact_phone text := nullif(trim(input ->> 'phone'), ''); primary_contact boolean := coalesce((input ->> 'isPrimary')::boolean, false); result_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.parties.manage') then raise exception 'Organisation party management permission is required' using errcode='42501'; end if;
  if contact_name is null or (contact_email is null and contact_phone is null) or (contact_email is not null and contact_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') or not exists (select 1 from public.business_parties where id=target_party_id and organisation_id=org_id) then raise exception 'Business party contact input is invalid' using errcode='22023'; end if;
  if primary_contact then update public.business_party_contacts set is_primary=false where party_id=target_party_id and is_primary; end if;
  insert into public.business_party_contacts (organisation_id, party_id, full_name, job_title, email, phone, is_primary) values (org_id, target_party_id, contact_name, contact_title, contact_email, contact_phone, primary_contact) returning id into result_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'business_party_contact_created', 'business_party_contact', result_id, input);
  return result_id;
end; $$;

create or replace function public.add_business_party_address(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; target_party_id uuid := (input ->> 'partyId')::uuid; target_type public.party_address_type := (input ->> 'addressType')::public.party_address_type; target_label text := nullif(trim(input ->> 'label'), ''); target_line_1 text := nullif(trim(input ->> 'line1'), ''); target_line_2 text := nullif(trim(input ->> 'line2'), ''); target_city text := nullif(trim(input ->> 'city'), ''); target_region text := nullif(trim(input ->> 'region'), ''); target_postal text := nullif(trim(input ->> 'postalCode'), ''); target_country char(2) := upper(coalesce(nullif(trim(input ->> 'countryCode'), ''), 'TZ')); primary_address boolean := coalesce((input ->> 'isPrimary')::boolean, false); result_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.parties.manage') then raise exception 'Organisation party management permission is required' using errcode='42501'; end if;
  if target_type is null or target_label is null or target_line_1 is null or target_country !~ '^[A-Z]{2}$' or not exists (select 1 from public.business_parties where id=target_party_id and organisation_id=org_id) then raise exception 'Business party address input is invalid' using errcode='22023'; end if;
  if primary_address then update public.business_party_addresses set is_primary=false where party_id=target_party_id and address_type=target_type and is_primary; end if;
  insert into public.business_party_addresses (organisation_id, party_id, address_type, label, line_1, line_2, city, region, postal_code, country_code, is_primary) values (org_id, target_party_id, target_type, target_label, target_line_1, target_line_2, target_city, target_region, target_postal, target_country, primary_address) returning id into result_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state) values (org_id, auth.uid(), 'business_party_address_created', 'business_party_address', result_id, input);
  return result_id;
end; $$;

create or replace function public.create_custom_role(input jsonb) returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; role_code text := lower(nullif(trim(input ->> 'code'), '')); role_name text := nullif(trim(input ->> 'name'), ''); role_scope public.scope_type := (input ->> 'defaultScope')::public.scope_type; permission_codes text[] := array(select jsonb_array_elements_text(coalesce(input -> 'permissionCodes','[]'::jsonb))); role_id uuid;
begin
 if not private.has_organisation_permission(org_id,'organisation.roles.manage') then raise exception 'Organisation role management permission is required' using errcode='42501'; end if;
 if role_code is null or role_code !~ '^[a-z0-9_.-]{3,100}$' or role_name is null or role_scope not in ('organisation','company','branch','warehouse') or cardinality(permission_codes)=0 then raise exception 'Custom role input is invalid' using errcode='22023'; end if;
 if exists (select 1 from public.roles where organisation_id is null and code=role_code) then raise exception 'Custom role code conflicts with a system role' using errcode='23505'; end if;
 if exists (select 1 from unnest(permission_codes) code where code not in ('organisation.structure.manage','organisation.memberships.manage','organisation.audit.read','organisation.support_access.manage','organisation.localisation.manage','organisation.localisation.approve','organisation.parties.manage')) then raise exception 'Custom role contains unsupported permission' using errcode='22023'; end if;
 insert into public.roles (organisation_id,code,name,default_scope,is_system) values (org_id,role_code,role_name,role_scope,false) returning id into role_id;
 insert into public.role_permissions (role_id,permission_id) select role_id,id from public.permissions where code=any(permission_codes);
 insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (org_id,auth.uid(),'custom_role_created','role',role_id,input); return role_id;
end; $$;

revoke all on function public.create_business_party_category(jsonb), public.upsert_business_party(jsonb), public.add_business_party_contact(jsonb), public.add_business_party_address(jsonb) from public;
grant execute on function public.create_business_party_category(jsonb), public.upsert_business_party(jsonb), public.add_business_party_contact(jsonb), public.add_business_party_address(jsonb) to authenticated;
