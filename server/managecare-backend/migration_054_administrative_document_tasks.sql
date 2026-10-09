-- Priority and approved document-version workflow.

ALTER TABLE administrative_tasks
  ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'normal'
  CHECK (priority IN ('low', 'normal', 'high', 'urgent'));

CREATE INDEX IF NOT EXISTS administrative_tasks_business_priority_idx
  ON administrative_tasks (business_id, priority, due_at);
