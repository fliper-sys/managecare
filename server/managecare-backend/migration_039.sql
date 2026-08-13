-- Upgrades admin_work_items.assigned_to (free text) with a real FK so a
-- worker's own dashboard can filter "my jobs" by identity instead of
-- fuzzy name matching. assigned_to (text) is kept as-is for backward
-- compatible display of rows created before this migration.
ALTER TABLE admin_work_items
  ADD COLUMN IF NOT EXISTS assigned_to_worker_id UUID REFERENCES managecare_workers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_admin_work_items_assigned_worker
  ON admin_work_items(assigned_to_worker_id, status);
