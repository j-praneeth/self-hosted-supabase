-- Reviewers and other non-admin users need to see department names when
-- reviewing GRNs / masters, but the default `has_permission('departments','read')`
-- policy denies them. Departments are a reference list — make SELECT open to any
-- authenticated user. Writes stay permission-gated by the existing _ins/_upd/_del
-- policies.

drop policy if exists departments_sel on public.departments;

create policy departments_sel on public.departments
  for select to authenticated using (true);

notify pgrst, 'reload schema';
