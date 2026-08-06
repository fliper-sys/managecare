-- Subscription flow columns/tables, porting lib/services/subscription_service.dart
-- off Firestore. Both the business-level (primary) and per-user fallback
-- paths are replicated, matching the existing Firestore field sets.

ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_family TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_business_type TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_amount DECIMAL(12,2);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_receipt_url TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_status TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_review_status TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_synced_at TIMESTAMPTZ;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_business_id UUID REFERENCES businesses(id) ON DELETE SET NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_plan TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_tier TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_family TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_business_type TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS has_active_subscription BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_status TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_start_date TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_payment_required BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_receipt_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_amount DECIMAL(12,2);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_activated_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS subscription_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID,
  business_id UUID REFERENCES businesses(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  plan_id TEXT,
  plan_tier TEXT,
  plan_family TEXT,
  amount DECIMAL(12,2),
  receipt_url TEXT,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_subscription_events_user ON subscription_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_subscription_events_business ON subscription_events(business_id, created_at DESC);
