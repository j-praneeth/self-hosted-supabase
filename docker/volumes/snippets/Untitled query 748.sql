-- ============================================================================
-- SEED: one TEST login per role (excluding System Admin).
--
--   Password (all users): Citta@123
--   Employee codes:        MEG-0001 … MEG-0007
--
-- For every seeded role except "System Admin" this creates:
--   • an auth.users row (bcrypt password via pgcrypto) + matching auth.identities
--   • an Active employee with an explicit MEG-000X code + a role-appropriate
--     department (departments.id is the text dept code), linked to the user
--   • profiles.employee_id ↔ employees.user_id wiring (profile row itself is
--     created by the on_auth_user_created → handle_new_user() trigger)
--   • the role grant via employee_roles
--
-- Idempotent: re-running will not duplicate users, employees, or role grants.
--
-- ⚠️  DEV / QA TESTING ONLY — do NOT apply to a production database. The
--     passwords here are shared and well-known.
-- ============================================================================

DO $$
DECLARE
  rec     record;
  v_uid   uuid;
  v_emp   uuid;
  v_role  uuid;
  v_dept  text;
BEGIN
  FOR rec IN
    SELECT * FROM (VALUES
      -- email,                 first,  last,         role name,     employee_code, dept code
      ('itadmin@test.com',   'Test', 'IT Admin',   'IT Admin',    'MEG-0001', 'IT'),
      ('hradmin@test.com',   'Test', 'HR Admin',   'HR Admin',    'MEG-0002', 'IT'),
      ('qa@test.com',        'Test', 'QA',         'QA',          'MEG-0003', 'QA'),
      ('analyst@test.com',   'Test', 'Lab Analyst','Lab Analyst', 'MEG-0004', 'PPL'),
      ('sro@test.com',       'Test', 'SRO',        'SRO',         'MEG-0005', 'SRO'),
      ('storeuser@test.com', 'Test', 'Store User', 'Store User',  'MEG-0006', 'STORES'),
      ('employee@test.com',  'Test', 'Employee',   'Employee',    'MEG-0007', 'MB')
    ) AS t(email, first_name, last_name, role_name, emp_code, dept_code)
  LOOP
    -- Resolve the role; skip this login if the role isn't seeded.
    SELECT id INTO v_role FROM public.roles WHERE name = rec.role_name LIMIT 1;
    IF v_role IS NULL THEN
      RAISE NOTICE 'Role "%" not found — skipping %', rec.role_name, rec.email;
      CONTINUE;
    END IF;

    -- Resolve the department (departments.id is the text dept code). NULL is
    -- fine — the employee just won't be tied to a department if it's missing.
    SELECT id INTO v_dept FROM public.departments WHERE id = rec.dept_code LIMIT 1;
    IF v_dept IS NULL THEN
      RAISE NOTICE 'Department "%" not found — % will have no department', rec.dept_code, rec.email;
    END IF;

    -- 1) Employee FIRST (explicit MEG code). Creating it before the auth.users
    --    insert keeps the employees table non-empty, so handle_new_user() never
    --    mistakes a test login for the first-ever (System Admin) bootstrap.
    SELECT id INTO v_emp FROM public.employees WHERE employee_code = rec.emp_code LIMIT 1;
    IF v_emp IS NULL THEN
      INSERT INTO public.employees(
        employee_code, first_name, last_name, office_email, user_name,
        department_id, record_status, status
      ) VALUES (
        rec.emp_code, rec.first_name, rec.last_name, rec.email,
        split_part(rec.email, '@', 1), v_dept, 'active', 'Active'
      ) RETURNING id INTO v_emp;
    ELSE
      -- Backfill the department on a pre-existing test employee.
      UPDATE public.employees
      SET department_id = COALESCE(department_id, v_dept)
      WHERE id = v_emp;
    END IF;

    -- 2) Auth user — only if this email doesn't already exist. The
    --    on_auth_user_created trigger creates the bare profiles row.
    SELECT id INTO v_uid FROM auth.users WHERE email = rec.email LIMIT 1;
    IF v_uid IS NULL THEN
      v_uid := gen_random_uuid();

      INSERT INTO auth.users(
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at,
        confirmation_token, recovery_token, email_change_token_new, email_change
      ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        v_uid, 'authenticated', 'authenticated', rec.email,
        crypt('Citta@123', gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object(
          'full_name', rec.first_name || ' ' || rec.last_name,
          'email_verified', true
        ),
        now(), now(),
        '', '', '', ''
      );

      INSERT INTO auth.identities(
        id, user_id, provider_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
      ) VALUES (
        gen_random_uuid(), v_uid, v_uid::text,
        jsonb_build_object('sub', v_uid::text, 'email', rec.email, 'email_verified', true),
        'email', now(), now(), now()
      );
    END IF;

    -- 3) Wire profile ↔ employee ↔ role.
    UPDATE public.employees SET user_id = COALESCE(user_id, v_uid) WHERE id = v_emp;
    UPDATE public.profiles  SET employee_id = v_emp WHERE id = v_uid;

    INSERT INTO public.employee_roles(employee_id, role_id)
    SELECT v_emp, v_role
    WHERE NOT EXISTS (
      SELECT 1 FROM public.employee_roles WHERE employee_id = v_emp AND role_id = v_role
    );

    RAISE NOTICE 'Seeded % (% / %) → role %', rec.email, rec.emp_code, v_uid, rec.role_name;
  END LOOP;
END $$;