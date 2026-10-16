-- Keep the most common pump upload history queries index-backed as records grow.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pump_uploads_business_uploaded_at
  ON pump_daily_uploads (business_id, uploaded_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pump_uploads_business_pump_approved_latest
  ON pump_daily_uploads (business_id, pump_id, uploaded_at DESC)
  WHERE COALESCE(status, 'approved') = 'approved';
