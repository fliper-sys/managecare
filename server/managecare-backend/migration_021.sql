-- PharmacyProvider defaults several actor-identifying fields to the string
-- literal 'system' when no real user id is available (userId ?? 'system'),
-- unlike every other table's created_by/performed_by_id columns which are
-- always populated with a real auth UUID. Widen these two pharmacy-specific
-- columns to TEXT so the 'system' sentinel doesn't fail as invalid UUID input.
ALTER TABLE pharmacy_prescriptions ALTER COLUMN prescriber_id TYPE TEXT;
ALTER TABLE pharmacy_audit_log ALTER COLUMN actor_id TYPE TEXT;
