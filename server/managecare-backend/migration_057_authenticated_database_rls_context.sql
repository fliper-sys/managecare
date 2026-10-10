-- Pass the verified Supabase user identity through each backend DB query.
-- These policies preserve user/business isolation for direct Postgres access.
BEGIN;

DROP POLICY IF EXISTS managecare_user_read ON business_members;
CREATE POLICY managecare_user_read ON business_members
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM businesses b
      WHERE b.id = business_members.business_id
        AND b.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS managecare_user_insert ON business_members;
CREATE POLICY managecare_user_insert ON business_members
  FOR INSERT
  WITH CHECK (
    (user_id = auth.uid() AND is_owner = false)
    OR EXISTS (
      SELECT 1 FROM businesses b
      WHERE b.id = business_members.business_id
        AND b.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS managecare_owner_update ON business_members;
CREATE POLICY managecare_owner_update ON business_members
  FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM businesses b
    WHERE b.id = business_members.business_id AND b.owner_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM businesses b
    WHERE b.id = business_members.business_id AND b.owner_id = auth.uid()
  ));

DROP POLICY IF EXISTS managecare_owner_delete ON business_members;
CREATE POLICY managecare_owner_delete ON business_members
  FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM businesses b
    WHERE b.id = business_members.business_id AND b.owner_id = auth.uid()
  ));

DROP POLICY IF EXISTS business_isolation ON procurements;
CREATE POLICY business_isolation ON procurements
  USING (business_id IN (
    SELECT business_id FROM business_members
    WHERE user_id = auth.uid() AND is_active = true
  ));

DROP POLICY IF EXISTS business_isolation ON distributors;
CREATE POLICY business_isolation ON distributors
  USING (business_id IN (
    SELECT business_id FROM business_members
    WHERE user_id = auth.uid() AND is_active = true
  ));

DROP POLICY IF EXISTS business_isolation ON sale_items;
CREATE POLICY business_isolation ON sale_items
  USING (EXISTS (
    SELECT 1 FROM sales s
    WHERE s.id = sale_items.sale_id
      AND s.business_id IN (
        SELECT business_id FROM business_members
        WHERE user_id = auth.uid() AND is_active = true
      )
  ));

COMMIT;
