-- The Worker Details "Edit Commission" screen (barber/stylist commission %)
-- has always written to a commission_percentage field, but no such column
-- ever existed on `workers` - the update silently no-op'd every time
-- (dropped by the request-building layer before it even reached this
-- table). Barbers/stylists have had no way to actually persist a
-- commission rate through that dialog.
ALTER TABLE workers ADD COLUMN IF NOT EXISTS commission_percentage DECIMAL(5,2) DEFAULT 0;
