BEGIN;

CREATE TABLE IF NOT EXISTS legacy_auth_identity_links (
  legacy_user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  auth_user_id UUID NOT NULL UNIQUE,
  email TEXT NOT NULL,
  linked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION active_legacy_auth_candidates()
RETURNS TABLE (legacy_user_id UUID, email TEXT, full_name TEXT)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT DISTINCT candidates.legacy_user_id, candidates.email, candidates.full_name
  FROM (
    SELECT p.id AS legacy_user_id, lower(trim(p.email)) AS email, p.full_name
    FROM profiles p
    JOIN businesses b ON b.owner_id = p.id
    WHERE b.is_active = true AND COALESCE(b.is_deleted, false) = false
      AND COALESCE(p.is_active, true) = true
      AND COALESCE(p.is_deleted, false) = false
      AND p.email IS NOT NULL AND trim(p.email) <> ''
    UNION
    SELECT w.id AS legacy_user_id, lower(trim(w.email)) AS email, w.full_name
    FROM workers w
    WHERE COALESCE(w.is_active, true) = true
      AND w.email IS NOT NULL AND trim(w.email) <> ''
  ) AS candidates;
$$;

CREATE OR REPLACE FUNCTION link_legacy_auth_identity(
  p_auth_user_id UUID,
  p_legacy_user_id UUID,
  p_email TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  legacy_profile profiles%ROWTYPE;
  owner_count INTEGER;
  worker_count INTEGER;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_legacy_user_id THEN
    RAISE EXCEPTION 'Legacy identity verification context mismatch';
  END IF;

  SELECT * INTO legacy_profile
  FROM profiles
  WHERE id = p_legacy_user_id
    AND lower(trim(email)) = lower(trim(p_email))
    AND COALESCE(is_active, true) = true
    AND COALESCE(is_deleted, false) = false;
  IF legacy_profile.id IS NULL AND NOT EXISTS (
    SELECT 1 FROM workers
    WHERE id = p_legacy_user_id
      AND lower(trim(email)) = lower(trim(p_email))
      AND COALESCE(is_active, true) = true
  ) THEN
    RAISE EXCEPTION 'Active legacy profile does not match verified email';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM businesses
    WHERE owner_id = p_legacy_user_id
      AND is_active = true AND COALESCE(is_deleted, false) = false
  ) AND NOT EXISTS (
    SELECT 1 FROM workers
    WHERE id = p_legacy_user_id
      AND COALESCE(is_active, true) = true
  ) THEN
    RAISE EXCEPTION 'Legacy identity has no active business or worker record';
  END IF;

  IF EXISTS (
    SELECT 1 FROM legacy_auth_identity_links
    WHERE (legacy_user_id = p_legacy_user_id AND auth_user_id <> p_auth_user_id)
       OR (auth_user_id = p_auth_user_id AND legacy_user_id <> p_legacy_user_id)
  ) THEN
    RAISE EXCEPTION 'Legacy identity is already linked to a different account';
  END IF;

  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_auth_user_id AND email IS NOT NULL
      AND lower(trim(email)) <> lower(trim(p_email))
  ) THEN
    RAISE EXCEPTION 'Auth user id is already associated with another profile email';
  END IF;

  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_legacy_user_id AND email IS NOT NULL
      AND lower(trim(email)) <> lower(trim(p_email))
  ) THEN
    RAISE EXCEPTION 'Legacy id is associated with a different profile email';
  END IF;

  IF EXISTS (
    SELECT 1 FROM businesses b
    JOIN business_members bm ON bm.business_id = b.id
    WHERE b.owner_id = p_legacy_user_id AND b.is_active = true
      AND COALESCE(b.is_deleted, false) = false
      AND bm.is_active = true AND bm.is_owner = true
      AND bm.user_id <> p_auth_user_id
  ) THEN
    RAISE EXCEPTION 'An owned business already has a different active owner membership';
  END IF;

  IF legacy_profile.id IS NULL THEN
    SELECT p_legacy_user_id, w.full_name, true, false
      INTO legacy_profile.id, legacy_profile.full_name,
           legacy_profile.is_active, legacy_profile.is_deleted
    FROM workers w WHERE w.id = p_legacy_user_id LIMIT 1;
  END IF;

  INSERT INTO profiles (id, full_name, is_active, is_deleted)
  VALUES (
    p_legacy_user_id,
    legacy_profile.full_name,
    true,
    false
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, full_name, is_active, is_deleted)
  VALUES (p_auth_user_id, legacy_profile.full_name, true, false)
  ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(profiles.full_name, EXCLUDED.full_name),
    is_active = true;

  INSERT INTO legacy_auth_identity_links (legacy_user_id, auth_user_id, email)
  VALUES (p_legacy_user_id, p_auth_user_id, lower(trim(p_email)))
  ON CONFLICT (legacy_user_id) DO NOTHING;

  INSERT INTO business_members (user_id, business_id, role, is_owner, is_active, permissions)
  SELECT p_auth_user_id, b.id, 'owner', true, true, '{}'::jsonb
  FROM businesses b
  WHERE b.owner_id = p_legacy_user_id
    AND b.is_active = true AND COALESCE(b.is_deleted, false) = false
  ON CONFLICT (user_id, business_id) DO NOTHING;
  GET DIAGNOSTICS owner_count = ROW_COUNT;

  INSERT INTO business_members (user_id, business_id, role, store_id, is_owner, is_active, permissions)
  SELECT p_auth_user_id, w.business_id, w.role, w.store_id, false, true,
         COALESCE(w.permissions, '{}'::jsonb)
  FROM workers w
  WHERE w.id = p_legacy_user_id AND COALESCE(w.is_active, true) = true
  ON CONFLICT (user_id, business_id) DO NOTHING;
  GET DIAGNOSTICS worker_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'owner_memberships_added', owner_count,
    'worker_memberships_added', worker_count
  );
END;
$$;

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
  WHERE w.id = COALESCE(
      (SELECT l.legacy_user_id FROM public.legacy_auth_identity_links l
       WHERE l.auth_user_id = NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID),
      NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID
    )
    AND COALESCE(w.is_active, true) = true
    AND b.is_active = true AND COALESCE(b.is_deleted, false) = false
  ORDER BY w.updated_at DESC NULLS LAST
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION ensure_worker_business_membership(
  p_user_id UUID,
  p_business_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  legacy_id UUID;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Authenticated user does not match worker';
  END IF;
  SELECT legacy_user_id INTO legacy_id FROM legacy_auth_identity_links
    WHERE auth_user_id = p_user_id;
  legacy_id := COALESCE(legacy_id, p_user_id);

  IF NOT EXISTS (
    SELECT 1 FROM workers w
    WHERE w.id = legacy_id AND w.business_id = p_business_id
      AND COALESCE(w.is_active, true) = true
  ) THEN
    RAISE EXCEPTION 'No active worker exists for this business';
  END IF;

  INSERT INTO business_members (user_id, business_id, role, is_owner, is_active, permissions, store_id)
  SELECT p_user_id, w.business_id, w.role, false, true,
         COALESCE(w.permissions, '{}'::jsonb), w.store_id
  FROM workers w
  WHERE w.id = legacy_id AND w.business_id = p_business_id
    AND COALESCE(w.is_active, true) = true
  ON CONFLICT (user_id, business_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION link_legacy_auth_identity(UUID, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION link_legacy_auth_identity(UUID, UUID, TEXT) TO managecare;
GRANT EXECUTE ON FUNCTION auth_worker_session() TO managecare;
GRANT EXECUTE ON FUNCTION ensure_worker_business_membership(UUID, UUID) TO managecare;
GRANT SELECT ON legacy_auth_identity_links TO managecare;
REVOKE ALL ON FUNCTION active_legacy_auth_candidates() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION active_legacy_auth_candidates() TO managecare;

COMMIT;
