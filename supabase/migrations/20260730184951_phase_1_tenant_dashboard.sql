create or replace function public.get_tenant_dashboard()
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare context_record public.user_tenant_contexts%rowtype; organisation_record public.organisations%rowtype; subscription_record record; implementation_record public.implementation_projects%rowtype;
begin
  select * into context_record from public.user_tenant_contexts where user_id = auth.uid();
  if context_record.user_id is null then return null; end if;
  if not exists (
    select 1 from public.organisation_memberships m join public.membership_scopes ms on ms.membership_id=m.id
    where m.organisation_id=context_record.organisation_id and m.user_id=auth.uid() and m.status='active' and (
      ms.scope='organisation' or (ms.scope='company' and (ms.scope_id=context_record.company_id or exists (select 1 from public.branches b where b.id=context_record.branch_id and b.company_id=ms.scope_id) or exists (select 1 from public.warehouses w where w.id=context_record.warehouse_id and w.company_id=ms.scope_id))) or (ms.scope='branch' and (ms.scope_id=context_record.branch_id or exists (select 1 from public.warehouses w where w.id=context_record.warehouse_id and w.branch_id=ms.scope_id))) or (ms.scope='warehouse' and ms.scope_id=context_record.warehouse_id)
    )
  ) then raise exception 'Saved tenant context exceeds membership scope' using errcode='42501'; end if;
  select * into organisation_record from public.organisations where id=context_record.organisation_id;
  select plan.name, plan.code into subscription_record from public.subscriptions subscription join public.subscription_plans plan on plan.id=subscription.plan_id where subscription.organisation_id=context_record.organisation_id;
  select * into implementation_record from public.implementation_projects where organisation_id=context_record.organisation_id;
  return jsonb_build_object(
    'organisationId', context_record.organisation_id,
    'organisationName', organisation_record.display_name,
    'organisationStatus', organisation_record.status,
    'companyId', context_record.company_id,
    'branchId', context_record.branch_id,
    'warehouseId', context_record.warehouse_id,
    'companyCount', (select count(*) from public.companies where organisation_id=context_record.organisation_id and (context_record.company_id is null or id=context_record.company_id)),
    'branchCount', (select count(*) from public.branches where organisation_id=context_record.organisation_id and (context_record.company_id is null or company_id=context_record.company_id) and (context_record.branch_id is null or id=context_record.branch_id)),
    'warehouseCount', (select count(*) from public.warehouses where organisation_id=context_record.organisation_id and (context_record.company_id is null or company_id=context_record.company_id) and (context_record.branch_id is null or branch_id=context_record.branch_id) and (context_record.warehouse_id is null or id=context_record.warehouse_id)),
    'subscriptionPlan', subscription_record.name,
    'subscriptionCode', subscription_record.code,
    'implementationStage', implementation_record.stage
  );
end; $$;

revoke all on function public.get_tenant_dashboard() from public;
grant execute on function public.get_tenant_dashboard() to authenticated;
