-- Remove legacy trg_audit_<table> triggers that were created by the baseline
-- migration (20260602142558). The 20260620130000_audit_full_coverage migration
-- later created audit_<table> triggers for the same tables but only dropped
-- the audit_* prefix, leaving both triggers active and causing every write to
-- produce two audit_logs rows.
--
-- This migration drops the old trg_audit_* triggers so only the canonical
-- audit_* triggers remain.

DO $$
DECLARE t text;
DECLARE legacy_tables text[] := ARRAY[
  'locations', 'grades', 'levels', 'departments', 'department_shift_hours',
  'job_titles', 'job_title_skills', 'job_title_competencies',
  'roles', 'role_permissions',
  'employees', 'employee_documents', 'employee_roles',
  'labs', 'lab_members', 'lab_test_report_approvers', 'lab_qa_members',
  'masters_group_members', 'technical_review_members',
  'profiles'
];
BEGIN
  FOREACH t IN ARRAY legacy_tables LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
       WHERE table_schema = 'public' AND table_name = t
    ) THEN
      EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', 'trg_audit_' || t, t);
    END IF;
  END LOOP;
END $$;
