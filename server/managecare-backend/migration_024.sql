-- Hotel vertical. Rooms, reservations, service orders, folio charges, and
-- a denormalized guest-profile sync table (write-mostly CRM view built from
-- reservation history - the app itself computes guest lists from
-- reservations client-side, this table exists for admin/reporting visibility).
CREATE TABLE IF NOT EXISTS hotel_rooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  number TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'single',
  capacity INTEGER NOT NULL DEFAULT 1,
  price_per_night DECIMAL(12,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'available',
  emoji TEXT,
  amenities JSONB NOT NULL DEFAULT '[]',
  images JSONB NOT NULL DEFAULT '[]',
  price_intervals JSONB NOT NULL DEFAULT '[]',
  floor INTEGER NOT NULL DEFAULT 1,
  rating DECIMAL(3,2) NOT NULL DEFAULT 4.5,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_hotel_rooms_business_id ON hotel_rooms(business_id);

CREATE TABLE IF NOT EXISTS hotel_reservations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  room_id UUID,
  room_number TEXT,
  guest_name TEXT NOT NULL,
  guest_email TEXT,
  guest_phone TEXT,
  guest_address TEXT,
  guest_nationality TEXT,
  guest_id_type TEXT,
  guest_id_number TEXT,
  next_of_kin_name TEXT,
  next_of_kin_phone TEXT,
  next_of_kin_relationship TEXT,
  booking_source TEXT NOT NULL DEFAULT 'walk-in',
  company_name TEXT,
  vehicle_plate_number TEXT,
  vehicle_make TEXT,
  vehicle_model TEXT,
  vehicle_color TEXT,
  check_in TIMESTAMPTZ NOT NULL,
  check_out TIMESTAMPTZ NOT NULL,
  adults INTEGER NOT NULL DEFAULT 1,
  children INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'confirmed',
  total_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  special_requests JSONB NOT NULL DEFAULT '[]',
  payment_status TEXT NOT NULL DEFAULT 'unpaid',
  cancel_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_hotel_reservations_business_id ON hotel_reservations(business_id);

CREATE TABLE IF NOT EXISTS hotel_service_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  room_id UUID,
  reservation_id UUID,
  service_name TEXT NOT NULL,
  description TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'pending',
  priority TEXT NOT NULL DEFAULT 'medium',
  charge_amount DECIMAL(12,2),
  source TEXT NOT NULL DEFAULT 'hotel_service',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_hotel_service_orders_business_id ON hotel_service_orders(business_id);

CREATE TABLE IF NOT EXISTS hotel_folio_charges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  reservation_id UUID NOT NULL,
  room_id UUID,
  room_number TEXT,
  description TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'extra',
  amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  source TEXT NOT NULL DEFAULT 'manual',
  source_order_id UUID,
  created_by_id UUID,
  created_by_name TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_hotel_folio_charges_business_id ON hotel_folio_charges(business_id);
CREATE INDEX IF NOT EXISTS idx_hotel_folio_charges_reservation_id ON hotel_folio_charges(reservation_id);

-- Keyed by a sanitized guest-identity string (email, else phone, else name),
-- not a UUID, since the app derives this key client-side to merge repeat
-- guests across reservations without a separate "create guest" step.
CREATE TABLE IF NOT EXISTS hotel_guests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  guest_key TEXT NOT NULL,
  guest_name TEXT,
  guest_email TEXT,
  guest_phone TEXT,
  guest_address TEXT,
  guest_nationality TEXT,
  guest_id_type TEXT,
  guest_id_number TEXT,
  next_of_kin_name TEXT,
  next_of_kin_phone TEXT,
  next_of_kin_relationship TEXT,
  booking_source TEXT,
  company_name TEXT,
  vehicle_plate_number TEXT,
  reservation_count INTEGER NOT NULL DEFAULT 0,
  checked_in_count INTEGER NOT NULL DEFAULT 0,
  total_spend DECIMAL(12,2) NOT NULL DEFAULT 0,
  guest_tier TEXT,
  tier_discount_rate DECIMAL(4,3),
  active_reservation_id UUID,
  current_room_id UUID,
  current_room_number TEXT,
  last_check_in TIMESTAMPTZ,
  last_check_out TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (business_id, guest_key)
);
CREATE INDEX IF NOT EXISTS idx_hotel_guests_business_id ON hotel_guests(business_id);
