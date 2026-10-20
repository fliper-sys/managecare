ALTER TABLE public.businesses
  DROP CONSTRAINT IF EXISTS businesses_business_type_check;

ALTER TABLE public.businesses
  ADD CONSTRAINT businesses_business_type_check
  CHECK (business_type = ANY (ARRAY[
    'pharmacy', 'retail', 'bakery', 'wholesale', 'agri', 'auto', 'salon',
    'barbershop', 'hotel', 'drink', 'restaurant', 'realestate', 'apartment',
    'gym', 'gas', 'petroleum', 'administrative'
  ]::text[]));
