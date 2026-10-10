-- Resolve a legacy worker's own business before membership exists, without
-- exposing worker or business rows through the general RLS policies.
CREATE OR REPLACE FUNCTION public.auth_worker_session()
RETURNS TABLE (
  business_id UUID,
  role TEXT,
  permissions JSONB,
  store_id UUID,
  is_active BOOLEAN,
  full_name TEXT,
  business JSONB
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT w.business_id, w.role, w.permissions, w.store_id, w.is_active,
         w.full_name, to_jsonb(b)
  FROM public.workers AS w
  JOIN public.businesses AS b ON b.id = w.business_id
  WHERE w.id = NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID
    AND COALESCE(w.is_active, true) = true
  ORDER BY w.updated_at DESC NULLS LAST
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.auth_worker_session() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.auth_worker_session() TO managecare;
