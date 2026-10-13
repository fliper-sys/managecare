BEGIN;

CREATE TABLE IF NOT EXISTS sale_item_inventory_deductions (
  sale_item_id UUID PRIMARY KEY,
  sale_id UUID NOT NULL,
  business_id UUID NOT NULL,
  product_id UUID NOT NULL,
  quantity DECIMAL(12, 3) NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE sale_item_inventory_deductions ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    EXECUTE 'REVOKE ALL ON sale_item_inventory_deductions FROM anon';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    EXECUTE 'REVOKE ALL ON sale_item_inventory_deductions FROM authenticated';
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_sale_item_inventory_deductions_business
  ON sale_item_inventory_deductions (business_id, applied_at DESC);

CREATE OR REPLACE FUNCTION deduct_fuel_stock_for_sale_item()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_business_id UUID;
  v_sale_type TEXT;
  v_product_search TEXT;
  v_quantity NUMERIC;
  v_claimed_sale_item UUID;
  v_updated_product UUID;
  v_is_fuel BOOLEAN;
BEGIN
  IF NEW.product_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT s.business_id, LOWER(COALESCE(s.sale_type, ''))
    INTO v_business_id, v_sale_type
    FROM sales s
   WHERE s.id = NEW.sale_id;

  IF v_business_id IS NULL THEN
    RAISE EXCEPTION 'Sale % does not exist', NEW.sale_id USING ERRCODE = '23503';
  END IF;

  SELECT LOWER(CONCAT_WS(' ', i.category, i.name, i.unit))
    INTO v_product_search
    FROM inventory i
   WHERE i.id = NEW.product_id AND i.business_id = v_business_id
   FOR UPDATE;

  v_is_fuel := v_sale_type ~ '(fuel|petrol|diesel|kerosene|petroleum|pump|gas)'
    OR COALESCE(v_product_search, '') ~ '(fuel|petrol|diesel|kerosene|petroleum|pms|ago|dpk|gas)';

  IF NOT v_is_fuel THEN
    RETURN NEW;
  END IF;

  v_quantity := COALESCE(NEW.quantity, 0) * COALESCE(NEW.sale_unit_multiplier, 1);
  IF v_quantity <= 0 THEN
    RAISE EXCEPTION 'Fuel sale quantity must be greater than zero';
  END IF;

  INSERT INTO sale_item_inventory_deductions
    (sale_item_id, sale_id, business_id, product_id, quantity)
  VALUES
    (NEW.id, NEW.sale_id, v_business_id, NEW.product_id, v_quantity)
  ON CONFLICT (sale_item_id) DO NOTHING
  RETURNING sale_item_id INTO v_claimed_sale_item;

  IF v_claimed_sale_item IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE inventory
     SET quantity = GREATEST(0, quantity - v_quantity), updated_at = NOW()
   WHERE id = NEW.product_id AND business_id = v_business_id
   RETURNING id INTO v_updated_product;

  IF v_updated_product IS NULL THEN
    RAISE EXCEPTION 'Fuel product % was not found in business inventory', NEW.product_id
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_deduct_fuel_stock_for_sale_item ON sale_items;
CREATE TRIGGER trg_deduct_fuel_stock_for_sale_item
  AFTER INSERT ON sale_items
  FOR EACH ROW
  EXECUTE FUNCTION deduct_fuel_stock_for_sale_item();

COMMIT;
