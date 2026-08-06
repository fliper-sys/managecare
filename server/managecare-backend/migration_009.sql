-- ============================================================
-- Migration 009: Missing database objects
-- Adds tables, indexes, and functions referenced by the
-- schema but not explicitly created in prior migrations.
-- ============================================================

-- BUSINESS MEMBERS (for multi-user access control)
-- Referenced in RLS policies and create_business_with_owner()
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pin TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS current_business_id UUID REFERENCES businesses(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deletion_reason TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE workers ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subscription_plan TEXT DEFAULT 'free';

CREATE TABLE IF NOT EXISTS business_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'staff',
  store_id UUID,
  is_owner BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  permissions JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, business_id)
);

CREATE INDEX IF NOT EXISTS idx_business_members_user ON business_members(user_id);
CREATE INDEX IF NOT EXISTS idx_business_members_business ON business_members(business_id);
CREATE INDEX IF NOT EXISTS idx_business_members_active ON business_members(business_id, is_active) WHERE is_active = true;
ALTER TABLE business_members ADD COLUMN IF NOT EXISTS store_id UUID;
ALTER TABLE business_members ENABLE ROW LEVEL SECURITY;

-- Realtime subscriptions table (for Socket.IO event tracking)
CREATE TABLE IF NOT EXISTS realtime_subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
  socket_id TEXT,
  rooms TEXT[] DEFAULT '{}',
  connected_at TIMESTAMPTZ DEFAULT NOW(),
  disconnected_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_realtime_user ON realtime_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_realtime_business ON realtime_subscriptions(business_id);

-- Sync audit log (for tracking offlineâ†’online sync activity)
CREATE TABLE IF NOT EXISTS sync_audit_log (
  id BIGSERIAL PRIMARY KEY,
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  action TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  conflict_resolved BOOLEAN DEFAULT false,
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ,
  payload JSONB,
  error_message TEXT,
  synced_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_audit_business ON sync_audit_log(business_id);
CREATE INDEX IF NOT EXISTS idx_sync_audit_status ON sync_audit_log(status);
CREATE INDEX IF NOT EXISTS idx_sync_audit_created ON sync_audit_log(created_at DESC);

-- ============================================================
-- MISSING INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_businesses_owner ON businesses(owner_id);
CREATE INDEX IF NOT EXISTS idx_businesses_active ON businesses(is_active);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_inventory_low_stock ON inventory(business_id, quantity, min_stock_level)
  WHERE quantity <= min_stock_level;

-- ============================================================
-- UPDATED FUNCTIONS
-- ============================================================

-- Updated get_daily_sales_summary with proper aggregation
CREATE OR REPLACE FUNCTION get_daily_sales_summary(
  p_business_id UUID,
  p_date DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
  total_sales DECIMAL(12,2),
  transaction_count BIGINT,
  average_sale DECIMAL(12,2),
  payment_breakdown JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(SUM(final_amount), 0)::DECIMAL(12,2) as total_sales,
    COUNT(*)::BIGINT as transaction_count,
    COALESCE(AVG(final_amount), 0)::DECIMAL(12,2) as average_sale,
    COALESCE(
      (SELECT jsonb_agg(pb)
       FROM (
         SELECT jsonb_build_object('method', payment_method, 'total', SUM(final_amount)::DECIMAL(12,2)) as pb
         FROM sales
         WHERE business_id = p_business_id
           AND DATE(created_at) = p_date
           AND status = 'completed'
         GROUP BY payment_method
       ) sub),
      '[]'::JSONB
    ) as payment_breakdown
  FROM sales
  WHERE business_id = p_business_id
    AND DATE(created_at) = p_date
    AND status = 'completed';
END;
$$ LANGUAGE plpgsql STABLE;

-- Get pending sync items count (for the dashboard badge)
CREATE OR REPLACE FUNCTION get_pending_sync_count(
  p_business_id UUID
) RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM sync_audit_log
  WHERE business_id = p_business_id
    AND status IN ('pending', 'failed');
  RETURN v_count;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- TRIGGER: Auto-update updated_at timestamp
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to key tables
DO $$
DECLARE
  tables TEXT[] := ARRAY['inventory', 'sales', 'customers', 'workers', 'expenses',
                          'procurements', 'distributors', 'business_members'];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY tables
  LOOP
    IF to_regclass(t) IS NULL THEN
      CONTINUE;
    END IF;

    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_%s_updated_at ON %s;', t, t
    );
    EXECUTE format(
      'CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %s
       FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();', t, t
    );
  END LOOP;
END;
$$;
