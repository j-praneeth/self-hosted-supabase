-- ============================================================
-- GRN workflow transitions: gate by the GRN's own model, not masters-group.
--
-- The generic guard validate_master_transition authorises status changes from
-- masters-GROUP categories (creator / reviewer / approver / qa_approver) or
-- masters:create / masters:approve. But material_grn (GRN) is an Operations
-- record: created by store/SRO users (no masters-group membership) and using
-- PER-RECORD assigned_reviewer_id / assigned_approver_id. So a GRN creator got
-- "Transition draft -> pending_review not allowed for current user" on Submit,
-- and the assigned reviewer/approver couldn't advance it.
--
-- This is rebuilt from the CURRENT function (20260609160100 — lowercase enum
-- values + QA-approval level + assigned-party checks) and adds a material_grn
-- allowance. ADDITIVE: every other master type and existing GRN approver keeps
-- its access; all existing SoD / reviewer-assignment / reject-comment RAISEs are
-- preserved.
--
-- MEDIA GRNs get an extra QA sign-off after the approver (entity_type-scoped
-- within the shared material_grn table):
--   draft -> pending_review -> pending_approval -> pending_qa_approval -> approved
-- All other GRN entity types keep the 3-step flow. The QA approver is assigned
-- from the masters-group "qa_approver" category. Frontend mirror: MasterWorkflowBar.
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_master_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  _allowed boolean := false;
  _creator uuid;
  _assigned_reviewer uuid;
  _assigned_approver uuid;
  _assigned_qa_approver uuid;
  _entity_type text;
  -- Master types that require a QA sign-off after the approver.
  _qa_gated boolean := NEW.master_type IN ('customer_agreements','vendor_agreements');
BEGIN
  BEGIN
    EXECUTE format('SELECT created_by, assigned_reviewer_id, assigned_approver_id, assigned_qa_approver_id FROM public.%I WHERE id=$1', NEW.master_type)
      INTO _creator, _assigned_reviewer, _assigned_approver, _assigned_qa_approver USING NEW.record_id;
  EXCEPTION WHEN OTHERS THEN
    _creator := NULL; _assigned_reviewer := NULL; _assigned_approver := NULL; _assigned_qa_approver := NULL;
  END;

  -- MEDIA GRNs require an extra QA sign-off after the approver. entity_type lives
  -- on the shared material_grn table, so QA-gate per row (only entity_type=MEDIA).
  IF NEW.master_type = 'material_grn' THEN
    BEGIN
      EXECUTE 'SELECT entity_type::text FROM public.material_grn WHERE id=$1' INTO _entity_type USING NEW.record_id;
    EXCEPTION WHEN OTHERS THEN _entity_type := NULL;
    END;
    IF _entity_type = 'MEDIA' THEN _qa_gated := true; END IF;
  END IF;

  IF NEW.from_status IN ('draft','rejected') AND NEW.to_status='pending_review' THEN
    _allowed := public.is_masters_group_member('creator'::member_category)
             OR public.has_permission('masters'::app_resource,'create');
    IF NEW.assigned_to IS NULL THEN
      RAISE EXCEPTION 'A reviewer must be selected before submitting for review';
    END IF;
    IF NEW.assigned_to = auth.uid() THEN
      RAISE EXCEPTION 'You cannot assign yourself as the reviewer';
    END IF;
    IF _creator IS NOT NULL AND NEW.assigned_to = _creator THEN
      RAISE EXCEPTION 'The reviewer cannot be the record creator';
    END IF;

  ELSIF NEW.from_status='pending_review' AND NEW.to_status='pending_approval' THEN
    _allowed := public.is_masters_group_member('reviewer'::member_category);
    IF _creator IS NOT NULL AND _creator = auth.uid() THEN
      RAISE EXCEPTION 'Reviewer cannot review own record';
    END IF;
    IF _assigned_reviewer IS NOT NULL AND _assigned_reviewer <> auth.uid() THEN
      RAISE EXCEPTION 'Only the assigned reviewer can forward this record';
    END IF;
    IF NEW.assigned_to IS NULL THEN
      RAISE EXCEPTION 'An approver must be selected before forwarding for approval';
    END IF;
    IF NEW.assigned_to = auth.uid() THEN
      RAISE EXCEPTION 'You cannot assign yourself as the approver';
    END IF;
    IF _creator IS NOT NULL AND NEW.assigned_to = _creator THEN
      RAISE EXCEPTION 'The approver cannot be the record creator';
    END IF;

  ELSIF NEW.from_status='pending_review' AND NEW.to_status='rejected' THEN
    _allowed := public.is_masters_group_member('reviewer'::member_category);
    IF NEW.comment IS NULL OR length(trim(NEW.comment))=0 THEN RAISE EXCEPTION 'Reject requires a comment'; END IF;
    IF _assigned_reviewer IS NOT NULL AND _assigned_reviewer <> auth.uid() THEN
      RAISE EXCEPTION 'Only the assigned reviewer can reject this record';
    END IF;

  -- Approver step — for QA-gated masters this forwards to QA instead of approving.
  ELSIF NEW.from_status='pending_approval' AND NEW.to_status='approved' THEN
    IF _qa_gated THEN
      RAISE EXCEPTION 'This agreement requires QA approval — forward it to a QA Approver instead of approving directly';
    END IF;
    _allowed := public.is_masters_group_member('approver'::member_category);
    IF _creator IS NOT NULL AND _creator = auth.uid() THEN
      RAISE EXCEPTION 'Approver cannot approve own record';
    END IF;
    IF _assigned_reviewer IS NOT NULL AND _assigned_reviewer = auth.uid() THEN
      RAISE EXCEPTION 'Approver cannot be the same person as the reviewer';
    END IF;
    IF _assigned_approver IS NOT NULL AND _assigned_approver <> auth.uid() THEN
      RAISE EXCEPTION 'Only the assigned approver can approve this record';
    END IF;

  ELSIF NEW.from_status='pending_approval' AND NEW.to_status='pending_qa_approval' THEN
    IF NOT _qa_gated THEN
      RAISE EXCEPTION 'QA approval does not apply to this record type';
    END IF;
    _allowed := public.is_masters_group_member('approver'::member_category);
    IF _creator IS NOT NULL AND _creator = auth.uid() THEN
      RAISE EXCEPTION 'Approver cannot approve own record';
    END IF;
    IF _assigned_reviewer IS NOT NULL AND _assigned_reviewer = auth.uid() THEN
      RAISE EXCEPTION 'Approver cannot be the same person as the reviewer';
    END IF;
    IF _assigned_approver IS NOT NULL AND _assigned_approver <> auth.uid() THEN
      RAISE EXCEPTION 'Only the assigned approver can forward this record to QA';
    END IF;
    IF NEW.assigned_to IS NULL THEN
      RAISE EXCEPTION 'A QA approver must be selected before forwarding for QA approval';
    END IF;
    IF NEW.assigned_to = auth.uid() THEN
      RAISE EXCEPTION 'You cannot assign yourself as the QA approver';
    END IF;
    IF _creator IS NOT NULL AND NEW.assigned_to = _creator THEN
      RAISE EXCEPTION 'The QA approver cannot be the record creator';
    END IF;
    IF _assigned_reviewer IS NOT NULL AND NEW.assigned_to = _assigned_reviewer THEN
      RAISE EXCEPTION 'The QA approver cannot be the assigned reviewer';
    END IF;

  ELSIF NEW.from_status='pending_qa_approval' AND NEW.to_status='approved' THEN
    _allowed := public.is_masters_group_member('qa_approver'::member_category);
    IF _creator IS NOT NULL AND _creator = auth.uid() THEN
      RAISE EXCEPTION 'QA approver cannot approve own record';
    END IF;
    IF _assigned_reviewer IS NOT NULL AND _assigned_reviewer = auth.uid() THEN
      RAISE EXCEPTION 'QA approver cannot be the same person as the reviewer';
    END IF;
    IF _assigned_approver IS NOT NULL AND _assigned_approver = auth.uid() THEN
      RAISE EXCEPTION 'QA approver cannot be the same person as the approver';
    END IF;
    IF _assigned_qa_approver IS NOT NULL AND _assigned_qa_approver <> auth.uid() THEN
      RAISE EXCEPTION 'Only the assigned QA approver can approve this record';
    END IF;

  ELSIF NEW.from_status='pending_qa_approval' AND NEW.to_status='rejected' THEN
    _allowed := public.is_masters_group_member('qa_approver'::member_category);
    IF NEW.comment IS NULL OR length(trim(NEW.comment))=0 THEN RAISE EXCEPTION 'Reject requires a comment'; END IF;
    IF _assigned_qa_approver IS NOT NULL AND _assigned_qa_approver <> auth.uid() THEN
      RAISE EXCEPTION 'Only the assigned QA approver can reject this record';
    END IF;

  ELSIF NEW.from_status='approved' AND NEW.to_status='inactive' THEN
    _allowed := public.is_masters_group_member('approver'::member_category);
  END IF;

  -- ── GRN-specific (additive): per-record assigned reviewer/approver model ──
  -- material_grn is an Operations record; its creator (or any operations:create
  -- holder) may submit, and the assigned reviewer/approver may advance/reject it,
  -- without masters-group membership. All RAISEs above (reviewer must be chosen,
  -- SoD, only-assigned-party, reject-needs-comment) have already run, so they
  -- still hold. For MEDIA GRN the approver forwards to QA (pending_qa_approval)
  -- and the assigned QA approver gives the final sign-off.
  IF NOT _allowed AND NEW.master_type = 'material_grn' THEN
    IF NEW.from_status IN ('draft','rejected') AND NEW.to_status='pending_review' THEN
      _allowed := (_creator IS NOT NULL AND _creator = auth.uid())
               OR public.has_permission('operations'::app_resource,'create');
    ELSIF NEW.from_status='pending_review' AND NEW.to_status IN ('pending_approval','rejected') THEN
      _allowed := (_assigned_reviewer IS NOT NULL AND _assigned_reviewer = auth.uid());
    ELSIF NEW.from_status='pending_approval' AND NEW.to_status IN ('approved','rejected','pending_qa_approval') THEN
      -- For MEDIA the base RAISEs on a direct approve (QA required); this allows the
      -- approver's approve (non-media) / forward-to-QA (media) / reject.
      _allowed := (_assigned_approver IS NOT NULL AND _assigned_approver = auth.uid());
      IF NEW.to_status='rejected' AND (NEW.comment IS NULL OR length(trim(NEW.comment))=0) THEN
        RAISE EXCEPTION 'Reject requires a comment';
      END IF;
    ELSIF NEW.from_status='pending_qa_approval' AND NEW.to_status IN ('approved','rejected') THEN
      _allowed := (_assigned_qa_approver IS NOT NULL AND _assigned_qa_approver = auth.uid());
      IF NEW.to_status='rejected' AND (NEW.comment IS NULL OR length(trim(NEW.comment))=0) THEN
        RAISE EXCEPTION 'Reject requires a comment';
      END IF;
    END IF;
  END IF;

  IF NOT _allowed AND public.has_permission('masters'::app_resource,'approve') THEN _allowed := true; END IF;
  IF NOT _allowed THEN RAISE EXCEPTION 'Transition % -> % not allowed for current user', NEW.from_status, NEW.to_status; END IF;
  RETURN NEW;
END $function$;

NOTIFY pgrst, 'reload schema';
