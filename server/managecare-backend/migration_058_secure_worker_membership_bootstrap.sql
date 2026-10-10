-- Restrict self-service membership creation to a verified active worker.
BEGIN;

DROP POLICY IF EXISTS managecare_user_insert ON business_members;
CREATE POLICY managecare_user_insert ON business_members
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM businesses b
      WHERE b.id = business_members.business_id
        AND b.owner_id = auth.uid()
        AND (
          business_members.is_owner = false
          OR (business_members.is_owner = true AND business_members.user_id = auth.uid())
        )
    )
  );

CREATE OR REPLACE FUNCTION ensure_worker_business_membership(
  p_user_id UUID,
  p_business_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Authenticated user does not match worker';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM workers w
    WHERE w.id = p_user_id
      AND w.business_id = p_business_id
      AND w.is_active = true
  ) THEN
    RAISE EXCEPTION 'No active worker exists for this business';
  END IF;

  INSERT INTO business_members (user_id, business_id, role, is_owner, is_active, permissions, store_id)
  SELECT w.id, w.business_id, w.role, false, true, COALESCE(w.permissions, '{}'::jsonb), w.store_id
  FROM workers w
  WHERE w.id = p_user_id
    AND w.business_id = p_business_id
    AND w.is_active = true
  ON CONFLICT (user_id, business_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION ensure_worker_business_membership(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ensure_worker_business_membership(UUID, UUID) TO managecare;

COMMIT;
