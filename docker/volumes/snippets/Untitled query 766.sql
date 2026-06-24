-- ════════════════════════════════════════════════════════════════════════
-- Customer Agreement business key → (customer + unit)
-- ════════════════════════════════════════════════════════════════════════
-- A customer may hold only ONE agreement per unit. Narrow the business key from
-- (customer_name_snapshot, agreement_type_name_snapshot, agreement_name, unit)
-- down to (customer_name_snapshot, unit) so a second agreement for the same
-- customer + unit — regardless of agreement type — is rejected as a duplicate.
--
-- Mirrors the client-side businessKey in src/lib/masters/registry.ts. Both are
-- real scalar text columns, so the enforce_master_business_key_unique trigger
-- normalizes them consistently (case-insensitive, whitespace-trimmed; blank ↔
-- blank still matches). New VERSIONS of a family carry supersedes_id and stay
-- exempt, so re-versioning an existing agreement is unaffected.
-- ════════════════════════════════════════════════════════════════════════

UPDATE public.master_business_keys
   SET key_columns = ARRAY['customer_name_snapshot','unit']
 WHERE master_table = 'customer_agreements';

NOTIFY pgrst, 'reload schema';
