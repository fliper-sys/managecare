BEGIN;

CREATE OR REPLACE FUNCTION public.is_active_business_owner(p_business_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.businesses AS b
    WHERE b.id = p_business_id
      AND b.is_active = true
      AND (
        b.owner_id = auth.uid()
        OR EXISTS (
          SELECT 1
          FROM public.business_members AS bm
          WHERE bm.business_id = b.id
            AND bm.user_id = auth.uid()
            AND bm.is_owner = true
            AND bm.is_active = true
        )
      )
  );
$$;

REVOKE ALL ON FUNCTION public.is_active_business_owner(UUID) FROM PUBLIC;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'managecare') THEN
    GRANT EXECUTE ON FUNCTION public.is_active_business_owner(UUID) TO managecare;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    GRANT EXECUTE ON FUNCTION public.is_active_business_owner(UUID) TO authenticated;
  END IF;
END;
$$;

DROP POLICY IF EXISTS managecare_user_insert ON public.business_members;
CREATE POLICY managecare_user_insert ON public.business_members
  FOR INSERT
  WITH CHECK (
    public.is_active_business_owner(business_id)
    AND (
      is_owner = false
      OR (is_owner = true AND user_id = auth.uid())
    )
  );

COMMIT;
