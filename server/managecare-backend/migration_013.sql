-- customer_provider.dart migration: the app tracks purchase-history
-- fields the original customers table didn't have.
ALTER TABLE customers ADD COLUMN IF NOT EXISTS total_transactions INTEGER NOT NULL DEFAULT 0;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS average_order_value DECIMAL(12,2) NOT NULL DEFAULT 0;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS first_purchase_date TIMESTAMPTZ;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS last_purchase_date TIMESTAMPTZ;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS notes TEXT;
