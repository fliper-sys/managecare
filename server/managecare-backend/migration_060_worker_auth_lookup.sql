-- Let the backend find an active worker during password authentication
-- without making worker rows generally visible through RLS.
CREATE OR REPLACE FUNCTION public.auth_worker_login_candidates(login_email TEXT)
RETURNS TABLE (
  id UUID,
  email TEXT,
  password_hash TEXT,
  full_name TEXT,
  role TEXT,
  is_active BOOLEAN
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT w.id, w.email, w.password_hash, w.full_name, w.role, w.is_active
  FROM public.workers AS w
  WHERE lower(w.email) = lower(trim(login_email))
    AND COALESCE(w.is_active, true) = true;
$$;

REVOKE ALL ON FUNCTION public.auth_worker_login_candidates(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.auth_worker_login_candidates(TEXT) TO managecare;
