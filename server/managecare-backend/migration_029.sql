-- Admin bulk-email audit log, replacing the Firestore `emails` collection
-- AdminProvider.sendEmailToUsers used to write to.
CREATE TABLE IF NOT EXISTS admin_email_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subject TEXT NOT NULL,
  body TEXT,
  recipients JSONB NOT NULL DEFAULT '[]',
  status TEXT NOT NULL DEFAULT 'processing',
  sent_count INTEGER NOT NULL DEFAULT 0,
  failed_count INTEGER NOT NULL DEFAULT 0,
  failed_recipients JSONB NOT NULL DEFAULT '[]',
  sent_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_admin_email_logs_created ON admin_email_logs(created_at DESC);
