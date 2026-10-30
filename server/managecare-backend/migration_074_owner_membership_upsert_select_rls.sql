BEGIN;

DROP POLICY IF EXISTS managecare_user_read ON public.business_members;
CREATE POLICY managecare_user_read ON public.business_members
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_active_business_owner(business_id)
  );

COMMIT;
