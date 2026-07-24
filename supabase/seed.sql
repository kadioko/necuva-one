insert into public.modules (code, name) values
  ('platform', 'Platform Administration'),
  ('sales', 'Sales'),
  ('purchasing', 'Purchasing'),
  ('inventory', 'Inventory'),
  ('accounting', 'Accounting'),
  ('hr', 'Human Resources'),
  ('assets', 'Fixed Assets'),
  ('projects', 'Projects')
on conflict (code) do nothing;

insert into public.permissions (code, module_code, description) values
  ('platform.organisations.read', 'platform', 'View organisation configuration'),
  ('platform.organisations.manage', 'platform', 'Manage organisation configuration'),
  ('platform.memberships.read', 'platform', 'View memberships'),
  ('platform.memberships.manage', 'platform', 'Manage memberships'),
  ('platform.audit.read', 'platform', 'View audit events'),
  ('platform.support.request', 'platform', 'Request support access')
on conflict (code) do nothing;

insert into public.subscription_plans (code, name, monthly_price_minor) values
  ('core', 'Necuva One Core', 25000000),
  ('growth', 'Necuva One Growth', 60000000),
  ('professional', 'Necuva One Professional', 120000000),
  ('enterprise', 'Necuva One Enterprise', null)
on conflict (code) do nothing;
