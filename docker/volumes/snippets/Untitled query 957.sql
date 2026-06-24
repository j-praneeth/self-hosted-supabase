-- Lab/lab_members SELECT must be open to any authenticated user.
-- ----------------------------------------------------------------------------
-- The Sample Registration screen ("Select Lead / HOD…") and the MRR/MRN
-- approver pool both read labs + lab_members to resolve a department's team
-- leads. The default policies require has_permission('labs','read'), which is
-- only granted to SRO / Lab Analyst / System Admin / IT Admin — so an SRO
-- registering a sample sees their own picker work, but a department user
-- (Purchase, QA, dept analyst, etc.) trying to request approval gets an empty
-- list because they can't SELECT lab_members. Reference data with no PII —
-- open the SELECT side; writes stay permission-gated.

drop policy if exists labs_sel on public.labs;
create policy labs_sel on public.labs
  for select to authenticated using (true);

drop policy if exists lab_members_sel on public.lab_members;
create policy lab_members_sel on public.lab_members
  for select to authenticated using (true);

notify pgrst, 'reload schema';
