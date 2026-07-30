create table public.user_tenant_contexts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  company_id uuid,
  branch_id uuid,
  warehouse_id uuid,
  updated_at timestamptz not null default now(),
  foreign key (company_id, organisation_id) references public.companies(id, organisation_id),
  foreign key (branch_id, organisation_id) references public.branches(id, organisation_id),
  foreign key (warehouse_id, organisation_id) references public.warehouses(id, organisation_id)
);

create trigger user_tenant_contexts_set_updated_at before update on public.user_tenant_contexts for each row execute function private.set_updated_at();
alter table public.user_tenant_contexts enable row level security;
alter table public.user_tenant_contexts force row level security;
grant select on public.user_tenant_contexts to authenticated;
create policy user_tenant_contexts_self_select on public.user_tenant_contexts for select using (user_id = auth.uid());

create or replace function private.has_organisation_permission(target_organisation_id uuid, permission_code text)
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.organisation_memberships m join public.membership_roles mr on mr.membership_id=m.id join public.roles r on r.id=mr.role_id join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id join public.membership_scopes ms on ms.membership_id=m.id
    where m.organisation_id=target_organisation_id and m.user_id=auth.uid() and m.status='active' and p.code=permission_code and (
      ms.scope='organisation' or (ms.scope='company' and exists (select 1 from public.companies c where c.id=ms.scope_id and c.organisation_id=target_organisation_id)) or (ms.scope='branch' and exists (select 1 from public.branches b where b.id=ms.scope_id and b.organisation_id=target_organisation_id)) or (ms.scope='warehouse' and exists (select 1 from public.warehouses w where w.id=ms.scope_id and w.organisation_id=target_organisation_id))
    )
  );
$$;

create or replace function public.set_tenant_context(input jsonb)
returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare target_org_id uuid := (input ->> 'organisationId')::uuid; target_company_id uuid := nullif(input ->> 'companyId','')::uuid; target_branch_id uuid := nullif(input ->> 'branchId','')::uuid; target_warehouse_id uuid := nullif(input ->> 'warehouseId','')::uuid;
begin
  if not private.is_active_organisation_member(target_org_id) then raise exception 'Active organisation membership is required' using errcode='42501'; end if;
  if target_company_id is not null and not exists (select 1 from public.companies c where c.id=target_company_id and c.organisation_id=target_org_id) then raise exception 'Company context is invalid' using errcode='23503'; end if;
  if target_branch_id is not null and not exists (select 1 from public.branches b where b.id=target_branch_id and b.organisation_id=target_org_id and (target_company_id is null or b.company_id=target_company_id)) then raise exception 'Branch context is invalid' using errcode='23503'; end if;
  if target_warehouse_id is not null and not exists (select 1 from public.warehouses w where w.id=target_warehouse_id and w.organisation_id=target_org_id and (target_branch_id is null or w.branch_id=target_branch_id)) then raise exception 'Warehouse context is invalid' using errcode='23503'; end if;
  if not exists (select 1 from public.organisation_memberships m join public.membership_scopes ms on ms.membership_id=m.id where m.organisation_id=target_org_id and m.user_id=auth.uid() and m.status='active' and (ms.scope='organisation' or (ms.scope='company' and (ms.scope_id=target_company_id or exists (select 1 from public.branches b where b.id=target_branch_id and b.company_id=ms.scope_id) or exists (select 1 from public.warehouses w where w.id=target_warehouse_id and w.company_id=ms.scope_id))) or (ms.scope='branch' and (ms.scope_id=target_branch_id or exists (select 1 from public.warehouses w where w.id=target_warehouse_id and w.branch_id=ms.scope_id))) or (ms.scope='warehouse' and ms.scope_id=target_warehouse_id))) then raise exception 'Selected context exceeds membership scope' using errcode='42501'; end if;
  insert into public.user_tenant_contexts (user_id,organisation_id,company_id,branch_id,warehouse_id) values (auth.uid(),target_org_id,target_company_id,target_branch_id,target_warehouse_id) on conflict (user_id) do update set organisation_id=excluded.organisation_id,company_id=excluded.company_id,branch_id=excluded.branch_id,warehouse_id=excluded.warehouse_id;
end; $$;
revoke all on function public.set_tenant_context(jsonb) from public;
grant execute on function public.set_tenant_context(jsonb) to authenticated;

create or replace function public.create_custom_role(input jsonb) returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; role_code text := lower(nullif(trim(input ->> 'code'), '')); role_name text := nullif(trim(input ->> 'name'), ''); role_scope public.scope_type := (input ->> 'defaultScope')::public.scope_type; permission_codes text[] := array(select jsonb_array_elements_text(coalesce(input -> 'permissionCodes','[]'::jsonb))); role_id uuid;
begin
 if not private.has_organisation_permission(org_id,'organisation.roles.manage') then raise exception 'Organisation role management permission is required' using errcode='42501'; end if;
 if role_code is null or role_code !~ '^[a-z0-9_.-]{3,100}$' or role_name is null or role_scope not in ('organisation','company','branch','warehouse') or cardinality(permission_codes)=0 then raise exception 'Custom role input is invalid' using errcode='22023'; end if;
 if exists (select 1 from public.roles where organisation_id is null and code=role_code) then raise exception 'Custom role code conflicts with a system role' using errcode='23505'; end if;
 if exists (select 1 from unnest(permission_codes) code where code not in ('organisation.structure.manage','organisation.memberships.manage','organisation.audit.read','organisation.support_access.manage')) then raise exception 'Custom role contains unsupported permission' using errcode='22023'; end if;
 insert into public.roles (organisation_id,code,name,default_scope,is_system) values (org_id,role_code,role_name,role_scope,false) returning id into role_id;
 insert into public.role_permissions (role_id,permission_id) select role_id,id from public.permissions where code=any(permission_codes);
 insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (org_id,auth.uid(),'custom_role_created','role',role_id,input); return role_id;
end; $$;

create or replace function public.manage_organisation_membership(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; user_id uuid := (input ->> 'userId')::uuid; role_code text := lower(nullif(trim(input ->> 'roleCode'), '')); target_membership_id uuid; role_id uuid; role_scope public.scope_type; member_status public.membership_status := coalesce((input ->> 'status')::public.membership_status,'active'); scope_type public.scope_type := coalesce((input ->> 'scope')::public.scope_type,'organisation'); target_scope_id uuid := nullif(input ->> 'scopeId','')::uuid;
begin
 if not private.has_organisation_permission(org_id,'organisation.memberships.manage') then raise exception 'Organisation membership management permission is required' using errcode='42501'; end if;
 select id,default_scope into role_id,role_scope from public.roles where code=role_code and (organisation_id is null or organisation_id=org_id) order by (organisation_id=org_id) desc limit 1;
 if role_id is null or role_scope<>scope_type then raise exception 'Role assignment or scope is invalid' using errcode='22023'; end if;
 if scope_type='organisation' then target_scope_id:=null; elsif scope_type='company' and not exists(select 1 from public.companies where id=target_scope_id and organisation_id=org_id) then raise exception 'Company scope is invalid' using errcode='23503'; elsif scope_type='branch' and not exists(select 1 from public.branches where id=target_scope_id and organisation_id=org_id) then raise exception 'Branch scope is invalid' using errcode='23503'; elsif scope_type='warehouse' and not exists(select 1 from public.warehouses where id=target_scope_id and organisation_id=org_id) then raise exception 'Warehouse scope is invalid' using errcode='23503'; end if;
 if not exists(select 1 from public.profiles where id=user_id) then raise exception 'User profile does not exist' using errcode='23503'; end if;
 insert into public.organisation_memberships(organisation_id,user_id,status,joined_at) values(org_id,user_id,member_status,case when member_status='active' then now() else null end) on conflict(organisation_id,user_id) do update set status=excluded.status returning id into target_membership_id;
 delete from public.membership_roles where membership_id=target_membership_id; delete from public.membership_scopes where membership_id=target_membership_id;
 insert into public.membership_roles(membership_id,role_id) values(target_membership_id,role_id); insert into public.membership_scopes(membership_id,scope,scope_id) values(target_membership_id,scope_type,target_scope_id);
 insert into public.audit_events(organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values(org_id,auth.uid(),'organisation_membership_managed','organisation_membership',target_membership_id,input); return target_membership_id;
end; $$;
