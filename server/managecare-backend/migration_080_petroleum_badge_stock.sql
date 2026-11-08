BEGIN;

CREATE TABLE IF NOT EXISTS petroleum_badge_batches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL, inventory_batch_id UUID REFERENCES inventory_batches(id) ON DELETE SET NULL,
  procurement_id UUID REFERENCES procurements(id) ON DELETE SET NULL,
  badge_code TEXT NOT NULL, source_type TEXT NOT NULL CHECK (source_type IN ('opening','procurement','adjustment')),
  received_quantity NUMERIC(14,3) NOT NULL CHECK (received_quantity >= 0), remaining_quantity NUMERIC(14,3) NOT NULL CHECK (remaining_quantity >= 0),
  unit TEXT, supplier_name TEXT, reference TEXT, created_by UUID, created_by_name TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (business_id, badge_code)
);
CREATE INDEX IF NOT EXISTS idx_petroleum_badges_product_fifo ON petroleum_badge_batches(business_id, product_id, created_at, id);
CREATE TABLE IF NOT EXISTS petroleum_badge_movements (
 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 product_id UUID NOT NULL, badge_batch_id UUID REFERENCES petroleum_badge_batches(id), movement_type TEXT NOT NULL,
 quantity NUMERIC(14,3) NOT NULL, source_type TEXT NOT NULL, source_id UUID, idempotency_key TEXT,
 note TEXT, created_by UUID, created_by_name TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 UNIQUE(business_id,idempotency_key)
);
CREATE INDEX IF NOT EXISTS idx_petroleum_badge_movements_product ON petroleum_badge_movements(business_id,product_id,created_at DESC);
CREATE TABLE IF NOT EXISTS petroleum_badge_allocations (
 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 badge_batch_id UUID NOT NULL REFERENCES petroleum_badge_batches(id), product_id UUID NOT NULL,
 sale_id UUID, sale_item_id UUID, upload_id UUID, quantity NUMERIC(14,3) NOT NULL CHECK(quantity > 0),
 reversed_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_petroleum_badge_allocations_upload ON petroleum_badge_allocations(business_id,upload_id);
CREATE TABLE IF NOT EXISTS petroleum_tank_dips (
 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 product_id UUID NOT NULL, actual_quantity NUMERIC(14,3) NOT NULL CHECK(actual_quantity >= 0), measured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 recorded_by UUID, recorded_by_name TEXT, note TEXT, expected_quantity NUMERIC(14,3), variance NUMERIC(14,3), created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_petroleum_tank_dips_product ON petroleum_tank_dips(business_id,product_id,measured_at DESC);
CREATE TABLE IF NOT EXISTS petroleum_deposit_allocations (
 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 deposit_id UUID NOT NULL REFERENCES petroleum_bank_deposits(id) ON DELETE CASCADE, cash_entry_id UUID REFERENCES petroleum_cash_entries(id) ON DELETE SET NULL,
 badge_batch_id UUID REFERENCES petroleum_badge_batches(id) ON DELETE SET NULL,
 amount NUMERIC(12,2) NOT NULL CHECK(amount > 0), note TEXT, created_by UUID, created_by_name TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE petroleum_deposit_allocations ADD COLUMN IF NOT EXISTS badge_batch_id UUID REFERENCES petroleum_badge_batches(id) ON DELETE SET NULL;
ALTER TABLE pump_daily_uploads ADD COLUMN IF NOT EXISTS badge_allocations JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE pump_daily_uploads ADD COLUMN IF NOT EXISTS selected_badge_id UUID REFERENCES petroleum_badge_batches(id) ON DELETE SET NULL;
ALTER TABLE pump_daily_uploads ADD COLUMN IF NOT EXISTS selected_badge_code TEXT;
ALTER TABLE petroleum_cash_entries ADD COLUMN IF NOT EXISTS badge_allocations JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS badge_allocations JSONB NOT NULL DEFAULT '[]'::jsonb;

-- Represent the pre-existing aggregate petroleum stock as an opening badge. No historical batch attribution is invented.
INSERT INTO petroleum_badge_batches(business_id,product_id,badge_code,source_type,received_quantity,remaining_quantity,unit)
SELECT i.business_id,i.id,'OPENING-'||i.id::text,'opening',GREATEST(COALESCE(i.quantity,0),0),GREATEST(COALESCE(i.quantity,0),0),i.unit
FROM inventory i
WHERE COALESCE(i.quantity,0)>0 AND LOWER(CONCAT_WS(' ',i.category,i.name,i.unit)) ~ '(fuel|petrol|diesel|kerosene|petroleum|pms|ago|dpk|gas)'
ON CONFLICT (business_id,badge_code) DO NOTHING;
INSERT INTO petroleum_badge_movements(business_id,product_id,badge_batch_id,movement_type,quantity,source_type,idempotency_key,note)
SELECT b.business_id,b.product_id,b.id,'opening',b.received_quantity,'opening','opening:'||b.id::text,'Opening balance from aggregate inventory'
FROM petroleum_badge_batches b WHERE b.source_type='opening'
ON CONFLICT (business_id,idempotency_key) DO NOTHING;

CREATE OR REPLACE FUNCTION deduct_fuel_stock_for_sale_item()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_business_id UUID; v_sale_type TEXT; v_product_search TEXT; v_quantity NUMERIC; v_claimed_sale_item UUID; v_updated_product UUID; v_is_fuel BOOLEAN; v_batch RECORD; v_take NUMERIC; v_left NUMERIC; v_allocations JSONB := '[]'::jsonb;
BEGIN
 IF NEW.product_id IS NULL THEN RETURN NEW; END IF;
 SELECT s.business_id,LOWER(COALESCE(s.sale_type,'')) INTO v_business_id,v_sale_type FROM sales s WHERE s.id=NEW.sale_id;
 IF v_business_id IS NULL THEN RAISE EXCEPTION 'Sale % does not exist',NEW.sale_id USING ERRCODE='23503'; END IF;
 SELECT LOWER(CONCAT_WS(' ',i.category,i.name,i.unit)) INTO v_product_search FROM inventory i WHERE i.id=NEW.product_id AND i.business_id=v_business_id FOR UPDATE;
 v_is_fuel:=v_sale_type ~ '(fuel|petrol|diesel|kerosene|petroleum|pump|gas)' OR COALESCE(v_product_search,'') ~ '(fuel|petrol|diesel|kerosene|petroleum|pms|ago|dpk|gas)';
 IF NOT v_is_fuel THEN RETURN NEW; END IF;
 v_quantity:=COALESCE(NEW.quantity,0)*COALESCE(NEW.sale_unit_multiplier,1);
 IF v_quantity<=0 THEN RAISE EXCEPTION 'Fuel sale quantity must be greater than zero'; END IF;
 INSERT INTO sale_item_inventory_deductions(sale_item_id,sale_id,business_id,product_id,quantity) VALUES(NEW.id,NEW.sale_id,v_business_id,NEW.product_id,v_quantity) ON CONFLICT(sale_item_id) DO NOTHING RETURNING sale_item_id INTO v_claimed_sale_item;
 IF v_claimed_sale_item IS NULL THEN RETURN NEW; END IF;
 v_left:=v_quantity;
 FOR v_batch IN SELECT * FROM petroleum_badge_batches WHERE business_id=v_business_id AND product_id=NEW.product_id AND remaining_quantity>0 ORDER BY created_at,id FOR UPDATE LOOP
   EXIT WHEN v_left<=0;
   v_take:=LEAST(v_left,v_batch.remaining_quantity);
   UPDATE petroleum_badge_batches SET remaining_quantity=remaining_quantity-v_take WHERE id=v_batch.id;
   INSERT INTO petroleum_badge_allocations(business_id,badge_batch_id,product_id,sale_id,sale_item_id,quantity) VALUES(v_business_id,v_batch.id,NEW.product_id,NEW.sale_id,NEW.id,v_take);
   INSERT INTO petroleum_badge_movements(business_id,product_id,badge_batch_id,movement_type,quantity,source_type,source_id,idempotency_key) VALUES(v_business_id,NEW.product_id,v_batch.id,'sale',-v_take,'sale_item',NEW.id,'sale:'||NEW.id::text||':'||v_batch.id::text) ON CONFLICT DO NOTHING;
   v_allocations:=v_allocations||jsonb_build_array(jsonb_build_object('badge_id',v_batch.id,'quantity',v_take));
   v_left:=v_left-v_take;
 END LOOP;
 IF v_left>0 THEN RAISE EXCEPTION 'Insufficient petroleum badge stock for product % (short by %)',NEW.product_id,v_left USING ERRCODE='23514'; END IF;
 UPDATE inventory SET quantity=(SELECT COALESCE(SUM(remaining_quantity),0) FROM petroleum_badge_batches WHERE business_id=v_business_id AND product_id=NEW.product_id),updated_at=NOW() WHERE id=NEW.product_id AND business_id=v_business_id RETURNING id INTO v_updated_product;
 IF v_updated_product IS NULL THEN RAISE EXCEPTION 'Fuel product % was not found in business inventory',NEW.product_id USING ERRCODE='23503'; END IF;
 UPDATE sale_items SET badge_allocations=v_allocations WHERE id=NEW.id;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_deduct_fuel_stock_for_sale_item ON sale_items;
CREATE TRIGGER trg_deduct_fuel_stock_for_sale_item AFTER INSERT ON sale_items FOR EACH ROW EXECUTE FUNCTION deduct_fuel_stock_for_sale_item();
COMMIT;
