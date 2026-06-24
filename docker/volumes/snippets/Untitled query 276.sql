CREATE OR REPLACE FUNCTION public.set_code_emp() RETURNS trigger
LANGUAGE plpgsql SET search_path = public AS $$
DECLARE _candidate text;
BEGIN
  IF (NEW.employee_code IS NULL OR NEW.employee_code = '') THEN
    IF TG_OP = 'INSERT' OR NEW.record_status <> 'draft'::record_status THEN
      LOOP
        _candidate := 'ML/'||lpad(nextval('emp_code_seq')::text, 5, '0');
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.employees WHERE employee_code = _candidate);
      END LOOP;
      NEW.employee_code := _candidate;
    END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_code_emp ON public.employees;
CREATE TRIGGER trg_code_emp BEFORE INSERT OR UPDATE ON public.employees
  FOR EACH ROW EXECUTE FUNCTION public.set_code_emp();

-- Confirm it took effect — the output MUST contain 'ML/' and NOT 'EMP-':
SELECT pg_get_functiondef('public.set_code_emp'::regproc);