-- Restaurant vertical. Menu items, orders, tables, reservations, staff and
-- waste records are all genuinely restaurant-only (unlike drugs/drinks,
-- nothing here maps onto the generic `inventory` table). Waste records do
-- reference `inventory` for the atomic stock-deduction transaction, reusing
-- the same `inventory_history` audit table other verticals already write to.
CREATE TABLE IF NOT EXISTS restaurant_menu_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'Menu',
  price DECIMAL(12,2) NOT NULL DEFAULT 0,
  cost DECIMAL(12,2),
  description TEXT,
  available BOOLEAN NOT NULL DEFAULT true,
  preparation_time INTEGER NOT NULL DEFAULT 15,
  image_url TEXT,
  rating DECIMAL(3,2),
  review_count INTEGER,
  inventory_product_id UUID,
  inventory_stock INTEGER,
  options JSONB NOT NULL DEFAULT '[]',
  ingredients JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_restaurant_menu_items_business_id ON restaurant_menu_items(business_id);

CREATE TABLE IF NOT EXISTS restaurant_tables (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  table_number INTEGER NOT NULL,
  capacity INTEGER NOT NULL DEFAULT 2,
  status TEXT NOT NULL DEFAULT 'available',
  assigned_waiter_id UUID,
  assigned_waiter_name TEXT,
  reserved_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_restaurant_tables_business_id ON restaurant_tables(business_id);

CREATE TABLE IF NOT EXISTS restaurant_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  table_id UUID,
  table_number INTEGER,
  -- Nullable, no FK: may reference a hotel guest/room once that vertical's
  -- schema exists (room-service style orders); opaque string until then.
  room_id TEXT,
  guest_id TEXT,
  order_target_type TEXT,
  order_target_label TEXT,
  customer_id UUID,
  customer_name TEXT,
  customer_phone TEXT,
  customer_email TEXT,
  items JSONB NOT NULL DEFAULT '[]',
  subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
  tax DECIMAL(12,2) NOT NULL DEFAULT 0,
  discount DECIMAL(12,2) NOT NULL DEFAULT 0,
  total DECIMAL(12,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  payment_status TEXT NOT NULL DEFAULT 'pending',
  assigned_chef_id UUID,
  assigned_waiter_id UUID,
  payment_methods JSONB NOT NULL DEFAULT '[]',
  payment_breakdown JSONB NOT NULL DEFAULT '[]',
  notes TEXT,
  order_type TEXT NOT NULL DEFAULT 'dine-in',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_restaurant_orders_business_id ON restaurant_orders(business_id);

CREATE TABLE IF NOT EXISTS restaurant_reservations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  guest_count INTEGER NOT NULL DEFAULT 1,
  reservation_date_time TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  special_requests TEXT,
  table_id UUID,
  table_number INTEGER,
  assigned_waiter_id UUID,
  assigned_waiter_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_restaurant_reservations_business_id ON restaurant_reservations(business_id);

CREATE TABLE IF NOT EXISTS restaurant_staff (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'waiter',
  active BOOLEAN NOT NULL DEFAULT true,
  sections JSONB NOT NULL DEFAULT '[]',
  permissions JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_restaurant_staff_business_id ON restaurant_staff(business_id);

CREATE TABLE IF NOT EXISTS restaurant_waste (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL,
  product_name TEXT NOT NULL,
  quantity DECIMAL(12,2) NOT NULL,
  unit TEXT NOT NULL DEFAULT 'unit',
  type TEXT NOT NULL DEFAULT 'spoilage',
  reason TEXT,
  cost_impact DECIMAL(12,2) NOT NULL DEFAULT 0,
  remaining_quantity DECIMAL(12,2) NOT NULL DEFAULT 0,
  recorded_by_id UUID,
  recorded_by_name TEXT,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_restaurant_waste_business_id ON restaurant_waste(business_id);
