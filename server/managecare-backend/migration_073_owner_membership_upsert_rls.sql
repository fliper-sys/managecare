BEGIN;

DROP POLICY IF EXISTS managecare_owner_update ON public.business_members;
CREATE POLICY managecare_owner_update ON public.business_members
  FOR UPDATE
  USING (public.is_active_business_owner(business_id))
  WITH CHECK (public.is_active_business_owner(business_id));

COMMIT;
