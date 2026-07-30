create type public.invitation_status as enum ('pending', 'sent', 'cancelled', 'expired');

create table public.organisation_invitations (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  email text not null check (email = lower(email) and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  invited_by uuid not null references public.profiles(id) on delete restrict,
  invited_user_id uuid references public.profiles(id) on delete set null,
  role_id uuid not null references public.roles(id) on delete restrict,
  scope public.scope_type not null,
  scope_id uuid,
  status public.invitation_status not null default 'pending',
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  check ((scope = 'organisation' and scope_id is null) or (scope in ('company', 'branch', 'warehouse') and scope_id is not null))
);
create unique index organisation_invitations_open_email_idx on public.organisation_invitations (organisation_id, email) where status in ('pending', 'sent');
alter table public.organisation_invitations enable row level security;
alter table public.organisation_invitations force row level security;
grant select on public.organisation_invitations to authenticated;
create policy organisation_invitations_authorised_select on public.organisation_invitations for select using (private.has_organisation_permission(organisation_id, 'organisation.memberships.manage') or invited_by = auth.uid());

create or replace function public.create_membership_invitation(input jsonb)
returns uuid language plpgsql security definer set search_path = pg_catalog, public as $$
declare org_id uuid := (input ->> 'organisationId')::uuid; invite_email text := lower(nullif(trim(input ->> 'email'), '')); role_code text := lower(nullif(trim(input ->> 'roleCode'), '')); role_id uuid; role_scope public.scope_type; invitation_scope public.scope_type := (input ->> 'scope')::public.scope_type; invitation_scope_id uuid := nullif(input ->> 'scopeId','')::uuid; invitation_id uuid;
begin
  if not private.has_organisation_permission(org_id, 'organisation.memberships.manage') then raise exception 'Organisation membership management permission is required' using errcode='42501'; end if;
  if invite_email is null or invite_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Invitation email is invalid' using errcode='22023'; end if;
  select id, default_scope into role_id, role_scope from public.roles where code=role_code and (organisation_id is null or organisation_id=org_id) order by (organisation_id=org_id) desc limit 1;
  if role_id is null or role_scope<>invitation_scope then raise exception 'Invitation role or scope is invalid' using errcode='22023'; end if;
  if invitation_scope='organisation' then invitation_scope_id:=null; elsif invitation_scope='company' and not exists(select 1 from public.companies where id=invitation_scope_id and organisation_id=org_id) then raise exception 'Company scope is invalid' using errcode='23503'; elsif invitation_scope='branch' and not exists(select 1 from public.branches where id=invitation_scope_id and organisation_id=org_id) then raise exception 'Branch scope is invalid' using errcode='23503'; elsif invitation_scope='warehouse' and not exists(select 1 from public.warehouses where id=invitation_scope_id and organisation_id=org_id) then raise exception 'Warehouse scope is invalid' using errcode='23503'; end if;
  insert into public.organisation_invitations (organisation_id,email,invited_by,role_id,scope,scope_id) values (org_id,invite_email,auth.uid(),role_id,invitation_scope,invitation_scope_id) returning id into invitation_id;
  insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (org_id,auth.uid(),'membership_invitation_created','organisation_invitation',invitation_id,input);
  return invitation_id;
end; $$;

create or replace function public.finalise_membership_invitation(target_invitation_id uuid, target_invited_user_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare invite public.organisation_invitations%rowtype; membership_id uuid;
begin
  select * into invite from public.organisation_invitations where id=target_invitation_id for update;
  if invite.id is null or invite.invited_by<>auth.uid() or invite.status<>'pending' or invite.expires_at<=now() then raise exception 'Invitation cannot be finalised' using errcode='42501'; end if;
  if not exists(select 1 from public.profiles where id=target_invited_user_id) then raise exception 'Invited user profile does not exist' using errcode='23503'; end if;
  insert into public.organisation_memberships (organisation_id,user_id,status) values (invite.organisation_id,target_invited_user_id,'invited') on conflict (organisation_id,user_id) do update set status='invited' returning id into membership_id;
  delete from public.membership_roles where membership_id=membership_id; delete from public.membership_scopes where membership_id=membership_id;
  insert into public.membership_roles (membership_id,role_id) values (membership_id,invite.role_id); insert into public.membership_scopes (membership_id,scope,scope_id) values (membership_id,invite.scope,invite.scope_id);
  update public.organisation_invitations set invited_user_id=target_invited_user_id,status='sent',sent_at=now() where id=target_invitation_id;
  insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (invite.organisation_id,auth.uid(),'membership_invitation_sent','organisation_invitation',target_invitation_id,jsonb_build_object('invitedUserId',target_invited_user_id));
end; $$;

create or replace function public.cancel_membership_invitation(target_invitation_id uuid, cancellation_reason text)
returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare invite public.organisation_invitations%rowtype;
begin
  select * into invite from public.organisation_invitations where id=target_invitation_id for update;
  if invite.id is null or invite.invited_by<>auth.uid() or invite.status<>'pending' then raise exception 'Invitation cannot be cancelled' using errcode='42501'; end if;
  update public.organisation_invitations set status='cancelled' where id=target_invitation_id;
  insert into public.audit_events (organisation_id,actor_user_id,action,entity_type,entity_id,after_state) values (invite.organisation_id,auth.uid(),'membership_invitation_cancelled','organisation_invitation',target_invitation_id,jsonb_build_object('reason',left(coalesce(cancellation_reason,''),250)));
end; $$;

revoke all on function public.create_membership_invitation(jsonb), public.finalise_membership_invitation(uuid,uuid), public.cancel_membership_invitation(uuid,text) from public;
grant execute on function public.create_membership_invitation(jsonb), public.finalise_membership_invitation(uuid,uuid), public.cancel_membership_invitation(uuid,text) to authenticated;
