-- Legacy worker imports may have NULL is_active despite being valid staff.
UPDATE workers
SET is_active = true
WHERE is_active IS NULL;
