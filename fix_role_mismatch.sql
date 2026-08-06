-- Fix business_members.role mismatches vs workers.role
-- 27 rows were bulk-reset to 'staff' at 2026-08-02 04:27:04 by an unknown
-- process; workers.role holds the correct, individually-maintained value.
BEGIN;
UPDATE business_members bm
SET role = w.role, updated_at = NOW()
FROM workers w
WHERE w.id = bm.user_id AND w.business_id = bm.business_id AND bm.role != w.role;
COMMIT;
