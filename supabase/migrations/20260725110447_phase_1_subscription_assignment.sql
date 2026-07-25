create or replace function public.assign_subscription_plan(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; plan_code text := lower(nullif(trim(input ->> 'planCode'), '')); plan_id uuid; subscription_id uuid;
begin
  if not private.has_platform_permission('platform.plans.manage') then raise exception 'Platform plan management permission is required' using errcode = '42501'; end if;
  select id into plan_id from public.subscription_plans where code = plan_code and is_active;
  if plan_id is null then raise exception 'Active subscription plan does not exist' using errcode = '23503'; end if;
  if not exists (select 1 from public.organisations where id = org_id) then raise exception 'Organisation does not exist' using errcode = '23503'; end if;
  insert into public.subscriptions (organisation_id, plan_id, starts_at) values (org_id, plan_id, now())
  on conflict (organisation_id) do update set plan_id = excluded.plan_id, starts_at = excluded.starts_at, ends_at = null
  returning id into subscription_id;
  insert into public.audit_events (organisation_id, actor_user_id, action, entity_type, entity_id, after_state)
  values (org_id, auth.uid(), 'subscription_plan_assigned', 'subscription', subscription_id, jsonb_build_object('planCode', plan_code));
  return subscription_id;
end; $$;
revoke all on function public.assign_subscription_plan(jsonb) from public;
grant execute on function public.assign_subscription_plan(jsonb) to authenticated;
