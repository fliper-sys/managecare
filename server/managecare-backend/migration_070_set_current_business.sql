BEGIN;

CREATE OR REPLACE FUNCTION public.set_current_business(p_business_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  auth_id UUID := auth.uid();
  legacy_id UUID;
BEGIN
  IF auth_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF to_regclass('public.legacy_auth_identity_links') IS NOT NULL THEN
    EXECUTE
      'SELECT legacy_user_id FROM public.legacy_auth_identity_links WHERE auth_user_id = $1'
      INTO legacy_id
      USING auth_id;
  END IF;
  legacy_id := COALESCE(legacy_id, auth_id);

  IF NOT EXISTS (
    SELECT 1
    FROM public.businesses b
    WHERE b.id = p_business_id
      AND b.is_active = true
      AND EXISTS (
        SELECT 1
        FROM public.business_members bm
        WHERE bm.business_id = b.id
          AND bm.user_id IN (auth_id, legacy_id)
          AND bm.is_active = true
      )
  ) THEN
    RAISE EXCEPTION 'You do not have access to this business';
  END IF;

  UPDATE public.profiles
  SET current_business_id = p_business_id,
      updated_at = NOW()
  WHERE id IN (auth_id, legacy_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.set_current_business(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_current_business(UUID) TO authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'managecare') THEN
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.set_current_business(UUID) TO managecare';
  END IF;
END;
$$;

NOTIFY pgrst, 'reload schema';

COMMIT;
