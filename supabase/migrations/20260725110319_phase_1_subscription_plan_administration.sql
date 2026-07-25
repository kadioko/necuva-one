insert into public.permissions (code, module_code, description)
values ('platform.plans.manage', 'platform', 'Create and update subscription plans')
on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code = 'platform.plans.manage'
where r.organisation_id is null and r.code = 'platform.owner' on conflict do nothing;

create or replace function public.upsert_subscription_plan(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare plan_code text := lower(nullif(trim(input ->> 'code'), '')); plan_name text := nullif(trim(input ->> 'name'), ''); price_minor bigint := nullif(input ->> 'monthlyPriceMinor', '')::bigint; enabled boolean := coalesce((input ->> 'isActive')::boolean, true); result_id uuid;
begin
  if not private.has_platform_permission('platform.plans.manage') then raise exception 'Platform plan management permission is required' using errcode = '42501'; end if;
  if plan_code is null or plan_code !~ '^[a-z0-9_.-]{3,100}$' or plan_name is null or price_minor < 0 then raise exception 'Subscription plan input is invalid' using errcode = '22023'; end if;
  insert into public.subscription_plans (code, name, monthly_price_minor, is_active) values (plan_code, plan_name, price_minor, enabled)
  on conflict (code) do update set name = excluded.name, monthly_price_minor = excluded.monthly_price_minor, is_active = excluded.is_active
  returning id into result_id;
  insert into public.audit_events (actor_user_id, action, entity_type, entity_id, after_state) values (auth.uid(), 'subscription_plan_upserted', 'subscription_plan', result_id, input);
  return result_id;
end; $$;
revoke all on function public.upsert_subscription_plan(jsonb) from public;
grant execute on function public.upsert_subscription_plan(jsonb) to authenticated;
