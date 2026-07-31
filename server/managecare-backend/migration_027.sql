-- Hospitality room/booking fields for private database sync.
ALTER TABLE hotel_rooms ADD COLUMN IF NOT EXISTS half_day_price DECIMAL(12,2) NOT NULL DEFAULT 0;
ALTER TABLE hotel_rooms ADD COLUMN IF NOT EXISTS size TEXT;
ALTER TABLE hotel_rooms ADD COLUMN IF NOT EXISTS bed_size TEXT;
ALTER TABLE hotel_rooms ADD COLUMN IF NOT EXISTS extra_details JSONB NOT NULL DEFAULT '{}';
ALTER TABLE hotel_rooms ADD COLUMN IF NOT EXISTS half_day_hours INTEGER NOT NULL DEFAULT 12;
ALTER TABLE hotel_rooms ADD COLUMN IF NOT EXISTS full_day_checkout_time TEXT NOT NULL DEFAULT '12:00';

ALTER TABLE hotel_reservations ADD COLUMN IF NOT EXISTS guest_sex TEXT;
ALTER TABLE hotel_reservations ADD COLUMN IF NOT EXISTS occupant_count INTEGER NOT NULL DEFAULT 1;
ALTER TABLE hotel_reservations ADD COLUMN IF NOT EXISTS vehicle_year TEXT;
ALTER TABLE hotel_reservations ADD COLUMN IF NOT EXISTS payment_method TEXT NOT NULL DEFAULT 'cash';
ALTER TABLE hotel_reservations ADD COLUMN IF NOT EXISTS mixed_payment_note TEXT;
ALTER TABLE hotel_reservations ADD COLUMN IF NOT EXISTS stay_duration_type TEXT NOT NULL DEFAULT 'full_day';
ALTER TABLE hotel_reservations ADD COLUMN IF NOT EXISTS estimated_arrival_at TIMESTAMPTZ;
