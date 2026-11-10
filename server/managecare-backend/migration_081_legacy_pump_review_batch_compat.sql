BEGIN;

-- Existing uploads predate mandatory batch accounting. New uploads use strict
-- batch stock checks; legacy pending rows retain the prior non-negative-stock
-- behavior when reviewed after the batch-ledger rollout.
ALTER TABLE pump_daily_uploads
  ADD COLUMN IF NOT EXISTS batch_stock_enforced BOOLEAN;
UPDATE pump_daily_uploads
   SET batch_stock_enforced = false
 WHERE batch_stock_enforced IS NULL;
ALTER TABLE pump_daily_uploads
  ALTER COLUMN batch_stock_enforced SET DEFAULT true,
  ALTER COLUMN batch_stock_enforced SET NOT NULL;

-- Link an approval sale to its source upload so the stock trigger can apply
-- the compatibility policy to old uploads only.
ALTER TABLE sales ADD COLUMN IF NOT EXISTS pump_upload_id UUID;
CREATE INDEX IF NOT EXISTS idx_sales_pump_upload_id
  ON sales (pump_upload_id) WHERE pump_upload_id IS NOT NULL;

CREATE OR REPLACE FUNCTION deduct_fuel_stock_for_sale_item()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
  v_business_id UUID;
  v_sale_type TEXT;
  v_pump_upload_id UUID;
  v_require_badge_stock BOOLEAN := true;
  v_product_search TEXT;
  v_quantity NUMERIC;
  v_claimed_sale_item UUID;
  v_updated_product UUID;
  v_is_fuel BOOLEAN;
  v_batch RECORD;
  v_take NUMERIC;
  v_left NUMERIC;
  v_allocations JSONB := '[]'::jsonb;
BEGIN
  IF NEW.product_id IS NULL THEN RETURN NEW; END IF;

  SELECT s.business_id, LOWER(COALESCE(s.sale_type,'')), s.pump_upload_id
    INTO v_business_id, v_sale_type, v_pump_upload_id
    FROM sales s WHERE s.id = NEW.sale_id;
  IF v_business_id IS NULL THEN
    RAISE EXCEPTION 'Sale % does not exist', NEW.sale_id USING ERRCODE='23503';
  END IF;

  IF v_pump_upload_id IS NOT NULL THEN
    SELECT COALESCE(p.batch_stock_enforced, false)
      INTO v_require_badge_stock
      FROM pump_daily_uploads p
     WHERE p.id = v_pump_upload_id AND p.business_id = v_business_id;
    IF NOT FOUND THEN v_require_badge_stock := true; END IF;
  END IF;

  SELECT LOWER(CONCAT_WS(' ', i.category, i.name, i.unit))
    INTO v_product_search
    FROM inventory i
   WHERE i.id = NEW.product_id AND i.business_id = v_business_id
   FOR UPDATE;
  v_is_fuel := v_sale_type ~ '(fuel|petrol|diesel|kerosene|petroleum|pump|gas)'
    OR COALESCE(v_product_search,'') ~ '(fuel|petrol|diesel|kerosene|petroleum|pms|ago|dpk|gas)';
  IF NOT v_is_fuel THEN RETURN NEW; END IF;

  v_quantity := COALESCE(NEW.quantity,0) * COALESCE(NEW.sale_unit_multiplier,1);
  IF v_quantity <= 0 THEN RAISE EXCEPTION 'Fuel sale quantity must be greater than zero'; END IF;

  INSERT INTO sale_item_inventory_deductions(sale_item_id,sale_id,business_id,product_id,quantity)
  VALUES(NEW.id,NEW.sale_id,v_business_id,NEW.product_id,v_quantity)
  ON CONFLICT(sale_item_id) DO NOTHING RETURNING sale_item_id INTO v_claimed_sale_item;
  IF v_claimed_sale_item IS NULL THEN RETURN NEW; END IF;

  v_left := v_quantity;
  FOR v_batch IN
    SELECT * FROM petroleum_badge_batches
     WHERE business_id=v_business_id AND product_id=NEW.product_id AND remaining_quantity>0
     ORDER BY created_at,id FOR UPDATE
  LOOP
    EXIT WHEN v_left <= 0;
    v_take := LEAST(v_left,v_batch.remaining_quantity);
    UPDATE petroleum_badge_batches SET remaining_quantity=remaining_quantity-v_take WHERE id=v_batch.id;
    INSERT INTO petroleum_badge_allocations(business_id,badge_batch_id,product_id,sale_id,sale_item_id,quantity)
    VALUES(v_business_id,v_batch.id,NEW.product_id,NEW.sale_id,NEW.id,v_take);
    INSERT INTO petroleum_badge_movements(business_id,product_id,badge_batch_id,movement_type,quantity,source_type,source_id,idempotency_key)
    VALUES(v_business_id,NEW.product_id,v_batch.id,'sale',-v_take,'sale_item',NEW.id,'sale:'||NEW.id::text||':'||v_batch.id::text)
    ON CONFLICT DO NOTHING;
    v_allocations := v_allocations || jsonb_build_array(jsonb_build_object('badge_id',v_batch.id,'quantity',v_take));
    v_left := v_left-v_take;
  END LOOP;

  IF v_left > 0 AND v_require_badge_stock THEN
    RAISE EXCEPTION 'Insufficient petroleum badge stock for product % (short by %)',NEW.product_id,v_left
      USING ERRCODE='23514';
  ELSIF v_left > 0 THEN
    -- Pre-batch uploads were historically approvable with stock floored at
    -- zero. Preserve that behavior, while recording the unallocated quantity
    -- rather than inventing a badge or allowing a negative batch balance.
    INSERT INTO petroleum_badge_movements(
      business_id,product_id,badge_batch_id,movement_type,quantity,source_type,source_id,idempotency_key,note
    ) VALUES(
      v_business_id,NEW.product_id,NULL,'legacy_unallocated_sale',-v_left,'legacy_pump_upload',NEW.id,
      'legacy-unallocated:'||NEW.id::text,
      'Legacy pump upload '||v_pump_upload_id::text||' approved with insufficient remaining badge stock'
    ) ON CONFLICT DO NOTHING;
    v_allocations := v_allocations || jsonb_build_array(
      jsonb_build_object('badge_id',NULL,'quantity',v_left,'legacy_unallocated',true)
    );
  END IF;

  UPDATE inventory
     SET quantity=(SELECT COALESCE(SUM(remaining_quantity),0) FROM petroleum_badge_batches
                    WHERE business_id=v_business_id AND product_id=NEW.product_id),
         updated_at=NOW()
   WHERE id=NEW.product_id AND business_id=v_business_id
   RETURNING id INTO v_updated_product;
  IF v_updated_product IS NULL THEN
    RAISE EXCEPTION 'Fuel product % was not found in business inventory',NEW.product_id USING ERRCODE='23503';
  END IF;
  UPDATE sale_items SET badge_allocations=v_allocations WHERE id=NEW.id;
  RETURN NEW;
END; $$;

COMMIT;
