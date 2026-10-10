ALTER TABLE administrative_tasks
  ADD COLUMN IF NOT EXISTS submitted_version_id UUID
  REFERENCES administrative_document_versions(id) ON DELETE SET NULL;