BEGIN;

ALTER TABLE public.businesses
  DROP CONSTRAINT IF EXISTS businesses_subscription_tier_check;

ALTER TABLE public.businesses
  ADD CONSTRAINT businesses_subscription_tier_check
  CHECK (subscription_tier IN (
    'free', 'basic', 'professional', 'enterprise',
    'tier1', 'tier2', 'tier3'
  ));

COMMIT;
