-- Seed migration: re-populate audit_logs with realistic demo activity.
--
-- This runs once after 20260620120000_audit_comprehensive.sql has put the new
-- columns / trigger / RPC in place. It is intentionally a separate file so the
-- schema migration stays focused on structure.
--
-- Migration semantics in Supabase: once `supabase db push` records this in
-- supabase_migrations.schema_migrations it won't run again, so the TRUNCATE
-- below only fires on the first apply per environment — safe for production.

BEGIN;

-- 0. Self-heal: an earlier draft of the schema migration referenced
--    `employees.full_name`, which doesn't exist (the table uses first_name +
--    last_name). Re-create the helper so the trigger and the seed agree on
--    the column shape, regardless of which version of the schema migration
--    ran on this environment.
CREATE OR REPLACE FUNCTION public.audit_actor_name(_actor uuid)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n text;
BEGIN
  IF _actor IS NULL THEN RETURN NULL; END IF;
  SELECT COALESCE(
           NULLIF(trim(concat_ws(' ', e.first_name, e.last_name)), ''),
           p.full_name,
           p.email
         )
    INTO n
    FROM public.profiles p
    LEFT JOIN public.employees e ON e.id = p.employee_id
   WHERE p.id = _actor
   LIMIT 1;
  RETURN n;
END $$;

-- 1. Clear the table first. RESTART IDENTITY is harmless on the uuid PK but
--    keeps the statement portable if the schema ever changes.
TRUNCATE TABLE public.audit_logs RESTART IDENTITY;

-- 2. Resolve a small actor pool from real data so foreign-key-ish lookups
--    (and the actor_name_snapshot) reflect actual employees. Falls back to
--    synthetic UUIDs if the source tables are empty (fresh database).
DO $$
DECLARE
  admin_id   uuid;
  admin_name text;
  qa_id      uuid;
  qa_name    text;
  stock_id   uuid;
  stock_name text;
  -- Reference IDs from operations tables (so the audit row points at a real
  -- record). Each is optional — if the table is empty we synthesize a UUID.
  grn_id     uuid;
  grn_no     text;
  mrn_id     uuid;
  mrn_no     text;
  min_id     uuid;
  min_no     text;
  con_id     uuid;
  con_no     text;
  adj_id     uuid;
  adj_no     text;
  std_id     uuid;
  std_name   text;
  chem_id    uuid;
  chem_name  text;
  emp_id     uuid;
  emp_name   text;
BEGIN
  -- Pick three distinct actors. Order by created_at so the same migration is
  -- deterministic for a given environment.
  SELECT p.id,
         COALESCE(NULLIF(trim(concat_ws(' ', e.first_name, e.last_name)), ''), p.full_name, p.email, 'System Admin')
    INTO admin_id, admin_name
    FROM public.profiles p
    LEFT JOIN public.employees e ON e.id = p.employee_id
   ORDER BY p.created_at ASC
   LIMIT 1;

  SELECT p.id,
         COALESCE(NULLIF(trim(concat_ws(' ', e.first_name, e.last_name)), ''), p.full_name, p.email, 'QA Approver')
    INTO qa_id, qa_name
    FROM public.profiles p
    LEFT JOIN public.employees e ON e.id = p.employee_id
   WHERE p.id IS DISTINCT FROM admin_id
   ORDER BY p.created_at ASC
   LIMIT 1;

  SELECT p.id,
         COALESCE(NULLIF(trim(concat_ws(' ', e.first_name, e.last_name)), ''), p.full_name, p.email, 'Stock Admin')
    INTO stock_id, stock_name
    FROM public.profiles p
    LEFT JOIN public.employees e ON e.id = p.employee_id
   WHERE p.id IS DISTINCT FROM admin_id
     AND p.id IS DISTINCT FROM qa_id
   ORDER BY p.created_at ASC
   LIMIT 1;

  -- Resolve sample target records — keep going even when a table is empty.
  -- Variables like `mrn_no` would shadow same-named columns inside the SELECT,
  -- so we table-qualify every column reference to keep plpgsql resolution
  -- unambiguous.
  SELECT mg.id, mg.grn_number      INTO grn_id, grn_no  FROM public.material_grn          mg ORDER BY mg.created_at DESC LIMIT 1;
  SELECT mr.id, mr.mrn_no          INTO mrn_id, mrn_no  FROM public.material_requisitions mr ORDER BY mr.created_at DESC LIMIT 1;
  SELECT mi.id, mi.min_no          INTO min_id, min_no  FROM public.material_issues       mi ORDER BY mi.created_at DESC LIMIT 1;
  SELECT mc.id, mc.consumption_no  INTO con_id, con_no  FROM public.material_consumptions mc ORDER BY mc.created_at DESC LIMIT 1;
  SELECT sa.id, sa.adjustment_no   INTO adj_id, adj_no  FROM public.stock_adjustments     sa ORDER BY sa.created_at DESC LIMIT 1;
  SELECT s.id,  s.name             INTO std_id, std_name  FROM public.standards  s ORDER BY s.created_at DESC LIMIT 1;
  SELECT c.id,  c.name             INTO chem_id, chem_name FROM public.chemicals c ORDER BY c.created_at DESC LIMIT 1;
  SELECT emp.id, NULLIF(trim(concat_ws(' ', emp.first_name, emp.last_name)), '')
    INTO emp_id, emp_name
    FROM public.employees emp ORDER BY emp.created_at DESC LIMIT 1;

  -- Fall back to synthetic IDs so the seed still demonstrates the audit row
  -- shape on a brand-new database.
  grn_id  := COALESCE(grn_id,  gen_random_uuid());  grn_no  := COALESCE(grn_no,  'GRN-DEMO-0234');
  mrn_id  := COALESCE(mrn_id,  gen_random_uuid());  mrn_no  := COALESCE(mrn_no,  'MRN-DEMO-0118');
  min_id  := COALESCE(min_id,  gen_random_uuid());  min_no  := COALESCE(min_no,  'MIN-DEMO-0094');
  con_id  := COALESCE(con_id,  gen_random_uuid());  con_no  := COALESCE(con_no,  'CON-DEMO-0061');
  adj_id  := COALESCE(adj_id,  gen_random_uuid());  adj_no  := COALESCE(adj_no,  'ADJ-DEMO-0027');
  std_id  := COALESCE(std_id,  gen_random_uuid());  std_name := COALESCE(std_name, 'Caffeine USP');
  chem_id := COALESCE(chem_id, gen_random_uuid()); chem_name := COALESCE(chem_name, 'Acetonitrile HPLC');
  emp_id  := COALESCE(emp_id,  gen_random_uuid());  emp_name := COALESCE(emp_name, 'New Hire');

  -- 3. Seed the dataset. Times relative to NOW so the activity feed renders
  --    "1m ago / 12m ago / 1h ago / 1d ago" naturally on first load.
  INSERT INTO public.audit_logs
    (id, table_name, record_id, action, actor_id, actor_name_snapshot,
     before, after, ip_address, user_agent, message, created_at)
  VALUES
    -- ── Logins / logouts ─────────────────────────────────────────────
    (gen_random_uuid(), 'auth', admin_id, 'LOGIN_SUCCESS', admin_id, admin_name,
     NULL, jsonb_build_object('email', 'admin@megsan.com'),
     '192.168.1.42'::inet,
     'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/138.0 Safari/537.36',
     'Logged in · EMP-00001',
     now() - interval '2 minutes'),

    (gen_random_uuid(), 'auth', qa_id, 'LOGIN_SUCCESS', qa_id, qa_name,
     NULL, jsonb_build_object('email', 'qa@megsan.com'),
     '10.0.4.118'::inet,
     'Mozilla/5.0 (Macintosh; Intel Mac OS X 14.5) AppleWebKit/605.1.15 Safari/605.1',
     'Logged in · EMP-00007',
     now() - interval '14 minutes'),

    (gen_random_uuid(), 'auth', stock_id, 'LOGIN_SUCCESS', stock_id, stock_name,
     NULL, jsonb_build_object('email', 'stock@megsan.com'),
     '172.31.128.5'::inet,
     'Mozilla/5.0 (iPad; CPU OS 17_4 like Mac OS X) AppleWebKit/605.1.15',
     'Logged in · EMP-00015',
     now() - interval '1 hour 6 minutes'),

    (gen_random_uuid(), 'auth', NULL, 'LOGIN_FAILED', NULL, NULL,
     NULL, jsonb_build_object('email', NULL),
     '203.0.113.7'::inet,
     'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
     'Login failed · unknown employee code EMP-999',
     now() - interval '4 hours 12 minutes'),

    -- ── E-signatures ────────────────────────────────────────────────
    (gen_random_uuid(), 'auth', qa_id, 'PASSWORD_VERIFY_SUCCESS', qa_id, qa_name,
     NULL, jsonb_build_object('email', 'qa@megsan.com'),
     '10.0.4.118'::inet,
     'Mozilla/5.0 (Macintosh; Intel Mac OS X 14.5) AppleWebKit/605.1.15 Safari/605.1',
     'E-signature confirmed',
     now() - interval '13 minutes'),

    (gen_random_uuid(), 'auth', stock_id, 'PASSWORD_VERIFY_FAILED', stock_id, stock_name,
     NULL, jsonb_build_object('email', 'stock@megsan.com'),
     '172.31.128.5'::inet,
     'Mozilla/5.0 (iPad; CPU OS 17_4 like Mac OS X) AppleWebKit/605.1.15',
     'E-signature failed (wrong password)',
     now() - interval '47 minutes'),

    -- ── Stock workflow transitions ──────────────────────────────────
    (gen_random_uuid(), 'material_grn', grn_id, 'INSERT', stock_id, stock_name,
     NULL, jsonb_build_object('grn_number', grn_no, 'status', 'draft'),
     '172.31.128.5'::inet, 'Mozilla/5.0', format('Created draft Material Grn %s', grn_no),
     now() - interval '3 hours 18 minutes'),

    (gen_random_uuid(), 'material_grn', grn_id, 'UPDATE', stock_id, stock_name,
     jsonb_build_object('grn_number', grn_no, 'status', 'draft'),
     jsonb_build_object('grn_number', grn_no, 'status', 'pending_review'),
     '172.31.128.5'::inet, 'Mozilla/5.0', format('Submitted for review · Material Grn %s', grn_no),
     now() - interval '3 hours'),

    (gen_random_uuid(), 'material_grn', grn_id, 'UPDATE', qa_id, qa_name,
     jsonb_build_object('grn_number', grn_no, 'status', 'pending_review'),
     jsonb_build_object('grn_number', grn_no, 'status', 'pending_approval'),
     '10.0.4.118'::inet, 'Mozilla/5.0', format('Sent for approval · Material Grn %s', grn_no),
     now() - interval '2 hours 40 minutes'),

    (gen_random_uuid(), 'material_grn', grn_id, 'UPDATE', admin_id, admin_name,
     jsonb_build_object('grn_number', grn_no, 'status', 'pending_approval'),
     jsonb_build_object('grn_number', grn_no, 'status', 'approved'),
     '192.168.1.42'::inet, 'Mozilla/5.0', format('Approved · Material Grn %s', grn_no),
     now() - interval '2 hours 10 minutes'),

    -- MRN → MIN → Receive flow
    (gen_random_uuid(), 'material_requisitions', mrn_id, 'INSERT', stock_id, stock_name,
     NULL, jsonb_build_object('mrn_no', mrn_no, 'status', 'draft'),
     '172.31.128.5'::inet, 'Mozilla/5.0', format('Created draft Material Requisitions %s', mrn_no),
     now() - interval '5 hours'),

    (gen_random_uuid(), 'material_requisitions', mrn_id, 'UPDATE', admin_id, admin_name,
     jsonb_build_object('mrn_no', mrn_no, 'status', 'pending_approval'),
     jsonb_build_object('mrn_no', mrn_no, 'status', 'approved'),
     '192.168.1.42'::inet, 'Mozilla/5.0', format('Approved · Material Requisitions %s', mrn_no),
     now() - interval '4 hours 30 minutes'),

    (gen_random_uuid(), 'material_issues', min_id, 'INSERT', stock_id, stock_name,
     NULL, jsonb_build_object('min_no', min_no, 'status', 'draft'),
     '172.31.128.5'::inet, 'Mozilla/5.0', format('Created draft Material Issues %s', min_no),
     now() - interval '4 hours'),

    (gen_random_uuid(), 'material_issues', min_id, 'UPDATE', admin_id, admin_name,
     jsonb_build_object('min_no', min_no, 'status', 'pending_approval'),
     jsonb_build_object('min_no', min_no, 'status', 'approved'),
     '192.168.1.42'::inet, 'Mozilla/5.0', format('Approved · Material Issues %s', min_no),
     now() - interval '3 hours 40 minutes'),

    -- Consumption
    (gen_random_uuid(), 'material_consumptions', con_id, 'INSERT', qa_id, qa_name,
     NULL, jsonb_build_object('consumption_no', con_no, 'status', 'draft'),
     '10.0.4.118'::inet, 'Mozilla/5.0', format('Created draft Material Consumptions %s', con_no),
     now() - interval '1 hour 50 minutes'),

    (gen_random_uuid(), 'material_consumptions', con_id, 'UPDATE', qa_id, qa_name,
     jsonb_build_object('consumption_no', con_no, 'status', 'draft'),
     jsonb_build_object('consumption_no', con_no, 'status', 'pending_review'),
     '10.0.4.118'::inet, 'Mozilla/5.0', format('Submitted for review · Material Consumptions %s', con_no),
     now() - interval '1 hour 35 minutes'),

    -- Stock adjustment rejection
    (gen_random_uuid(), 'stock_adjustments', adj_id, 'INSERT', stock_id, stock_name,
     NULL, jsonb_build_object('adjustment_no', adj_no, 'status', 'draft'),
     '172.31.128.5'::inet, 'Mozilla/5.0', format('Created draft Stock Adjustments %s', adj_no),
     now() - interval '6 hours'),

    (gen_random_uuid(), 'stock_adjustments', adj_id, 'UPDATE', admin_id, admin_name,
     jsonb_build_object('adjustment_no', adj_no, 'status', 'pending_approval'),
     jsonb_build_object('adjustment_no', adj_no, 'status', 'rejected'),
     '192.168.1.42'::inet, 'Mozilla/5.0', format('Rejected · Stock Adjustments %s', adj_no),
     now() - interval '5 hours 30 minutes'),

    -- ── Masters CRUD + status workflow ──────────────────────────────
    (gen_random_uuid(), 'standards', std_id, 'INSERT', qa_id, qa_name,
     NULL, jsonb_build_object('name', std_name, 'status', 'draft'),
     '10.0.4.118'::inet, 'Mozilla/5.0', format('Created draft Standards %s', std_name),
     now() - interval '1 day 2 hours'),

    (gen_random_uuid(), 'standards', std_id, 'UPDATE', admin_id, admin_name,
     jsonb_build_object('name', std_name, 'status', 'pending_qa_approval'),
     jsonb_build_object('name', std_name, 'status', 'approved'),
     '192.168.1.42'::inet, 'Mozilla/5.0', format('Approved · Standards %s', std_name),
     now() - interval '1 day 1 hour'),

    (gen_random_uuid(), 'chemicals', chem_id, 'UPDATE', admin_id, admin_name,
     jsonb_build_object('name', chem_name, 'enabled', true),
     jsonb_build_object('name', chem_name, 'enabled', false),
     '192.168.1.42'::inet, 'Mozilla/5.0', format('Deactivated Chemicals %s', chem_name),
     now() - interval '2 days'),

    -- ── HR / setup activity ─────────────────────────────────────────
    (gen_random_uuid(), 'employees', emp_id, 'INSERT', admin_id, admin_name,
     NULL, jsonb_build_object('full_name', emp_name, 'record_status', 'active'),
     '192.168.1.42'::inet, 'Mozilla/5.0', format('Created Employees %s', emp_name),
     now() - interval '3 days'),

    (gen_random_uuid(), 'employees', emp_id, 'UPDATE', admin_id, admin_name,
     jsonb_build_object('record_status', 'active'),
     jsonb_build_object('record_status', 'inactive'),
     '192.168.1.42'::inet, 'Mozilla/5.0', format('Deactivated Employees %s', emp_name),
     now() - interval '6 hours 45 minutes'),

    -- ── Older logout / login pair to show a full session ────────────
    (gen_random_uuid(), 'auth', admin_id, 'LOGOUT', admin_id, admin_name,
     NULL, NULL, '192.168.1.42'::inet, 'Mozilla/5.0',
     'Logged out',
     now() - interval '1 day 4 hours');

  RAISE NOTICE 'Audit logs seeded: % rows', (SELECT count(*) FROM public.audit_logs);
END $$;

COMMIT;
