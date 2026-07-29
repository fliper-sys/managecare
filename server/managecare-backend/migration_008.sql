-- ============================================================
-- Migration 008: Self-hosted push notifications
-- Replaces Firebase Cloud Messaging (FCM) with a self-hosted
-- solution using Socket.io + Postgres-backed notification queue.
-- ============================================================

-- Device tokens table: registers each device for push delivery
CREATE TABLE IF NOT EXISTS device_tokens (
  device_id    VARCHAR(255) PRIMARY KEY,
  user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  platform     VARCHAR(50) DEFAULT 'mobile',
  device_name  VARCHAR(255),
  last_seen    TIMESTAMPTZ DEFAULT NOW(),
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);

-- Notifications table: persisted notification queue
CREATE TABLE IF NOT EXISTS notifications (
  id           BIGSERIAL PRIMARY KEY,
  user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  business_id  UUID REFERENCES businesses(id) ON DELETE CASCADE,
  title        VARCHAR(255) NOT NULL,
  body         TEXT NOT NULL,
  type         VARCHAR(50) DEFAULT 'general',
  data         JSONB,
  is_read      BOOLEAN DEFAULT false,
  read_at      TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread
  ON notifications(user_id, is_read)
  WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_created_at
  ON notifications(created_at DESC);
