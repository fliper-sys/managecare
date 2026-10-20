BEGIN;

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
  legacy_worker workers%ROWTYPE;
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
  IF NOT FOUND AND NOT EXISTS (
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
      AND bm.user_id NOT IN (p_auth_user_id, p_legacy_user_id)
  ) THEN
    RAISE EXCEPTION 'An owned business already has a different active owner membership';
  END IF;

  -- Load the complete legacy records after verifying the identity. The
  -- initial email-matched profile lookup may not find worker-backed profiles.
  SELECT * INTO legacy_profile
  FROM profiles
  WHERE id = p_legacy_user_id
    AND COALESCE(is_active, true) = true
    AND COALESCE(is_deleted, false) = false;

  SELECT * INTO legacy_worker
  FROM workers
  WHERE id = p_legacy_user_id
    AND COALESCE(is_active, true) = true;

  INSERT INTO profiles (
    id, full_name, phone_number, address, job_title, photo_url, pin,
    current_business_id, is_active, is_deleted
  )
  VALUES (
    p_legacy_user_id,
    COALESCE(NULLIF(btrim(legacy_profile.full_name), ''), NULLIF(btrim(legacy_worker.full_name), '')),
    COALESCE(NULLIF(btrim(legacy_profile.phone_number), ''), NULLIF(btrim(legacy_worker.phone), '')),
    NULLIF(btrim(legacy_profile.address), ''),
    NULLIF(btrim(legacy_profile.job_title), ''),
    NULLIF(btrim(legacy_profile.photo_url), ''),
    COALESCE(legacy_profile.pin, legacy_worker.pin),
    COALESCE(legacy_profile.current_business_id, legacy_worker.business_id),
    true,
    false
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(NULLIF(btrim(profiles.full_name), ''), EXCLUDED.full_name),
    phone_number = COALESCE(NULLIF(btrim(profiles.phone_number), ''), EXCLUDED.phone_number),
    address = COALESCE(NULLIF(btrim(profiles.address), ''), EXCLUDED.address),
    job_title = COALESCE(NULLIF(btrim(profiles.job_title), ''), EXCLUDED.job_title),
    photo_url = COALESCE(NULLIF(btrim(profiles.photo_url), ''), EXCLUDED.photo_url),
    pin = COALESCE(profiles.pin, EXCLUDED.pin),
    current_business_id = COALESCE(profiles.current_business_id, EXCLUDED.current_business_id);

  INSERT INTO profiles (
    id, email, full_name, phone_number, address, job_title, photo_url, pin,
    current_business_id, is_active, is_deleted
  )
  VALUES (
    p_auth_user_id,
    CASE WHEN NOT EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id <> p_auth_user_id
        AND lower(btrim(p.email)) = lower(btrim(p_email))
    ) THEN lower(btrim(p_email)) END,
    COALESCE(NULLIF(btrim(legacy_profile.full_name), ''), NULLIF(btrim(legacy_worker.full_name), '')),
    COALESCE(NULLIF(btrim(legacy_profile.phone_number), ''), NULLIF(btrim(legacy_worker.phone), '')),
    NULLIF(btrim(legacy_profile.address), ''),
    NULLIF(btrim(legacy_profile.job_title), ''),
    NULLIF(btrim(legacy_profile.photo_url), ''),
    COALESCE(legacy_profile.pin, legacy_worker.pin),
    COALESCE(legacy_profile.current_business_id, legacy_worker.business_id),
    true,
    false
  )
  ON CONFLICT (id) DO UPDATE SET
    email = COALESCE(NULLIF(btrim(profiles.email), ''), EXCLUDED.email),
    full_name = COALESCE(NULLIF(btrim(profiles.full_name), ''), EXCLUDED.full_name),
    phone_number = COALESCE(NULLIF(btrim(profiles.phone_number), ''), EXCLUDED.phone_number),
    address = COALESCE(NULLIF(btrim(profiles.address), ''), EXCLUDED.address),
    job_title = COALESCE(NULLIF(btrim(profiles.job_title), ''), EXCLUDED.job_title),
    photo_url = COALESCE(NULLIF(btrim(profiles.photo_url), ''), EXCLUDED.photo_url),
    pin = COALESCE(profiles.pin, EXCLUDED.pin),
    current_business_id = COALESCE(profiles.current_business_id, EXCLUDED.current_business_id),
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

COMMIT;
