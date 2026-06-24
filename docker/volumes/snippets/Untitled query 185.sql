-- ════════════════════════════════════════════════════════════════════════
-- Seed: Megascan team employees + auth logins + group memberships
-- ════════════════════════════════════════════════════════════════════════
-- Source: handover sheet (Technical Reviewers / Users / Masters Creators /
-- Masters Approvals). Same idempotent pattern as 20260610000000 — re-running
-- updates names/passwords without duplicating rows.
--
-- Email + password convention (per request):
--   • office_email / auth email = "<normalized employee_code>@megsan.com"
--     where the code is lowercased and slashes are stripped, e.g.
--       ML/0071             → ml0071@megsan.com
--       ML/PEND-Harish      → mlpend-harish@megsan.com
--   • initial password (shared): Citta@123  — change on first sign-in.
--
-- Placeholders for codes the sheet did not list ("ML/PEND-<first-name>"):
--   Harish, Ramu, Sudhakar, Praveen Reddy, Somesh, Kiran, Chaitanya,
--   p. Venkatesh, P. Ravindranath. Replace these once HR confirms — both
--   employee_code AND office_email update via a single UPDATE.
--
-- Conflict note: the sheet lists ML/0528 against BOTH N. Raju (Trace-Metals
-- user) and P. Ravindranath (Masters Approver). We keep ML/0528 on N. Raju
-- (has a department) and stamp Ravindranath as 'ML/PEND-Ravindranath' until
-- HR confirms which is correct.
--
-- Department resolution: joins on departments.code (TL / TL-MS / PC / PL /
-- MB / SRO / PS / QA). The sheet's "Pharma-PC / Pharma-PL / Trace-Metals /
-- Trace-MS / Purchase" labels map to PC / PL / TL / TL-MS / PS.
-- ════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  _password text := 'Citta@123';
  -- NOTE: JSON does not support `--` comments. Group labels (Technical
  -- Reviewers / Users / Masters Creators / Masters Approvals) are encoded via
  -- the `mg` ("masters_group" category) and `tr` ("technical_review" flag)
  -- keys on each row — not inline comments.
  seed jsonb := '[
    {"code":"ML/0071",            "first":"P.",      "last":"Narasa Reddy",  "dept":"TL",    "mg":"reviewer","tr":true},
    {"code":"ML/0421",            "first":"G.",      "last":"Naveen Kumar",  "dept":"TL-MS", "mg":"reviewer","tr":true},
    {"code":"ML/PEND-Harish",     "first":"Harish",  "last":"-",             "dept":"PC",    "mg":"reviewer","tr":true},
    {"code":"ML/0493",            "first":"D.",      "last":"Krishna Tulasi","dept":"TL-MS", "mg":"reviewer","tr":true},
    {"code":"ML/PEND-Ramu",       "first":"Ramu",    "last":"-",             "dept":"PL",    "mg":"reviewer","tr":true},
    {"code":"ML/0653",            "first":"D.",      "last":"Nakusha",       "dept":"PL",    "mg":"reviewer","tr":true},
    {"code":"ML/PEND-Sudhakar",   "first":"Sudhakar","last":"-",             "dept":"MB",    "mg":"reviewer","tr":true},
    {"code":"ML/0863",            "first":"P.",      "last":"Praveen",       "dept":"SRO",   "mg":"reviewer","tr":true},
    {"code":"ML/PEND-PraveenReddy","first":"Praveen","last":"Reddy",         "dept":"PS",    "mg":"reviewer","tr":true},
    {"code":"ML/0935",            "first":"N.",      "last":"Ramesh",        "dept":"QA",    "mg":"reviewer","tr":true},
    {"code":"ML/0528",            "first":"N.",      "last":"Raju",          "dept":"TL"},
    {"code":"ML/0598",            "first":"Sampath", "last":"-",             "dept":"TL-MS"},
    {"code":"ML/0563",            "first":"CH.",     "last":"Bhargavi",      "dept":"PC"},
    {"code":"ML/0614",            "first":"Sneha",   "last":"-",             "dept":"TL-MS"},
    {"code":"ML/PEND-Somesh",     "first":"Somesh",  "last":"-",             "dept":"PL"},
    {"code":"ML/0852",            "first":"Mounika", "last":"-",             "dept":"PL"},
    {"code":"ML/PEND-Kiran",      "first":"Kiran",   "last":"-",             "dept":"MB"},
    {"code":"ML/PEND-Chaitanya",  "first":"Chaitanya","last":"-",            "dept":"SRO"},
    {"code":"ML/0965",            "first":"Konda",   "last":"Reddy",         "dept":"PS"},
    {"code":"ML/0609",            "first":"Venkatesh","last":"I.",           "mg":"creator"},
    {"code":"ML/PEND-pVenkatesh", "first":"p.",      "last":"Venkatesh",     "mg":"creator"},
    {"code":"ML/0854",            "first":"Manasa",  "last":"-",             "mg":"creator"},
    {"code":"ML/PEND-Ravindranath","first":"P.",     "last":"Ravindranath",  "mg":"approver"},
    {"code":"ML/0168",            "first":"K.",      "last":"Manoj Kumar"}
  ]'::jsonb;
  item     jsonb;
  _code    text;
  _first   text;
  _last    text;
  _dept    text;
  _mg      text;
  _tr      boolean;
  _email   text;
  _full    text;
  _user_id uuid;
  _emp_id  uuid;
  _dept_id uuid;
BEGIN
  FOR item IN SELECT * FROM jsonb_array_elements(seed) LOOP
    _code  := item->>'code';
    _first := item->>'first';
    _last  := item->>'last';
    _dept  := item->>'dept';
    _mg    := item->>'mg';
    _tr    := COALESCE((item->>'tr')::boolean, false);
    -- Normalize the code into an email-safe local-part: lowercase, strip '/'.
    _email := lower(replace(_code, '/', '')) || '@megsan.com';
    _full  := concat_ws(' ', _first, _last);

    -- Resolve department by code (may be NULL for cross-team members).
    _dept_id := NULL;
    IF _dept IS NOT NULL THEN
      SELECT id INTO _dept_id FROM public.departments WHERE code = _dept LIMIT 1;
      IF _dept_id IS NULL THEN
        RAISE EXCEPTION 'Seed dept % not found in public.departments', _dept;
      END IF;
    END IF;

    -- 1. auth.users — bcrypted password, email pre-confirmed so sign-in works
    --    immediately without an email link.
    SELECT id INTO _user_id FROM auth.users WHERE lower(email) = _email LIMIT 1;
    IF _user_id IS NULL THEN
      _user_id := gen_random_uuid();
      INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at,
        confirmation_token, email_change, email_change_token_new, recovery_token
      ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        _user_id,
        'authenticated', 'authenticated',
        _email,
        crypt(_password, gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('full_name', _full),
        now(), now(),
        '', '', '', ''
      );
    ELSE
      UPDATE auth.users
         SET encrypted_password = crypt(_password, gen_salt('bf')),
             email_confirmed_at = COALESCE(email_confirmed_at, now()),
             updated_at         = now()
       WHERE id = _user_id;
    END IF;

    -- 2. auth.identities — GoTrue requires this for password sign-in.
    IF NOT EXISTS (
      SELECT 1 FROM auth.identities WHERE user_id = _user_id AND provider = 'email'
    ) THEN
      INSERT INTO auth.identities (
        id, user_id, provider, provider_id,
        identity_data, last_sign_in_at, created_at, updated_at
      ) VALUES (
        gen_random_uuid(), _user_id, 'email', _user_id::text,
        jsonb_build_object('sub', _user_id::text, 'email', _email, 'email_verified', true),
        now(), now(), now()
      );
    END IF;

    -- 3. employees row.
    INSERT INTO public.employees (
      employee_code, first_name, last_name, office_email, department_id,
      user_id, status, record_status
    ) VALUES (
      _code, _first, _last, _email, _dept_id,
      _user_id, 'Active', 'active'
    )
    ON CONFLICT (employee_code) DO UPDATE
      SET first_name    = EXCLUDED.first_name,
          last_name     = EXCLUDED.last_name,
          office_email  = EXCLUDED.office_email,
          department_id = COALESCE(EXCLUDED.department_id, public.employees.department_id),
          user_id       = EXCLUDED.user_id,
          status        = 'Active',
          record_status = 'active',
          updated_at    = now()
    RETURNING id INTO _emp_id;

    IF _emp_id IS NULL THEN
      SELECT id INTO _emp_id FROM public.employees WHERE employee_code = _code;
    END IF;

    -- 4. profiles row links auth.users → employees.
    INSERT INTO public.profiles (id, email, full_name, employee_id)
    VALUES (_user_id, _email, _full, _emp_id)
    ON CONFLICT (id) DO UPDATE
      SET email       = EXCLUDED.email,
          full_name   = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
          employee_id = EXCLUDED.employee_id;

    -- 5. Masters Group membership (optional).
    IF _mg IS NOT NULL THEN
      INSERT INTO public.masters_group_members (employee_id, member_category, status)
      VALUES (_emp_id, _mg::public.member_category, 'active')
      ON CONFLICT DO NOTHING;
    END IF;

    -- 6. Technical Review department membership (reviewers only).
    IF _tr AND _dept_id IS NOT NULL THEN
      INSERT INTO public.technical_review_members (department_id, employee_id, status)
      VALUES (_dept_id, _emp_id, 'active'::public.record_status)
      ON CONFLICT (department_id, employee_id) DO NOTHING;
    END IF;

    RAISE NOTICE 'Seeded % (%) → emp=%, user=%, mg=%, tr=%',
      _code, _email, _emp_id, _user_id, COALESCE(_mg,'-'), _tr;
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
