BEGIN;

-- Restore profile fields from the verified legacy identity associated with
-- each auth account. Existing non-empty auth profile values always win.
UPDATE public.profiles AS target
SET
  email = COALESCE(
    NULLIF(btrim(target.email), ''),
    CASE
      WHEN NULLIF(btrim(link.email), '') IS NOT NULL
       AND NOT EXISTS (
         SELECT 1
         FROM public.profiles AS other_profile
         WHERE other_profile.id <> target.id
           AND lower(btrim(other_profile.email)) = lower(btrim(link.email))
       )
      THEN lower(btrim(link.email))
    END
  ),
  full_name = COALESCE(
    NULLIF(btrim(target.full_name), ''),
    NULLIF(btrim(legacy_profile.full_name), ''),
    NULLIF(btrim(legacy_worker.full_name), '')
  ),
  phone_number = COALESCE(
    NULLIF(btrim(target.phone_number), ''),
    NULLIF(btrim(legacy_profile.phone_number), ''),
    NULLIF(btrim(legacy_worker.phone), '')
  ),
  address = COALESCE(NULLIF(btrim(target.address), ''), NULLIF(btrim(legacy_profile.address), '')),
  job_title = COALESCE(NULLIF(btrim(target.job_title), ''), NULLIF(btrim(legacy_profile.job_title), '')),
  photo_url = COALESCE(NULLIF(btrim(target.photo_url), ''), NULLIF(btrim(legacy_profile.photo_url), '')),
  pin = COALESCE(target.pin, legacy_profile.pin, legacy_worker.pin),
  current_business_id = COALESCE(
    target.current_business_id,
    legacy_profile.current_business_id,
    legacy_worker.business_id
  ),
  updated_at = NOW()
FROM public.legacy_auth_identity_links AS link
LEFT JOIN public.profiles AS legacy_profile
  ON legacy_profile.id = link.legacy_user_id
LEFT JOIN public.workers AS legacy_worker
  ON legacy_worker.id = link.legacy_user_id
WHERE target.id = link.auth_user_id
  AND (
    (NULLIF(btrim(target.email), '') IS NULL AND NULLIF(btrim(link.email), '') IS NOT NULL)
    OR (NULLIF(btrim(target.full_name), '') IS NULL AND (
      NULLIF(btrim(legacy_profile.full_name), '') IS NOT NULL
      OR NULLIF(btrim(legacy_worker.full_name), '') IS NOT NULL
    ))
    OR (NULLIF(btrim(target.phone_number), '') IS NULL AND (
      NULLIF(btrim(legacy_profile.phone_number), '') IS NOT NULL
      OR NULLIF(btrim(legacy_worker.phone), '') IS NOT NULL
    ))
    OR (NULLIF(btrim(target.address), '') IS NULL AND NULLIF(btrim(legacy_profile.address), '') IS NOT NULL)
    OR (NULLIF(btrim(target.job_title), '') IS NULL AND NULLIF(btrim(legacy_profile.job_title), '') IS NOT NULL)
    OR (NULLIF(btrim(target.photo_url), '') IS NULL AND NULLIF(btrim(legacy_profile.photo_url), '') IS NOT NULL)
    OR (target.pin IS NULL AND (legacy_profile.pin IS NOT NULL OR legacy_worker.pin IS NOT NULL))
    OR (target.current_business_id IS NULL AND (
      legacy_profile.current_business_id IS NOT NULL
      OR legacy_worker.business_id IS NOT NULL
    ))
  );

-- Include the verified link email in the merged profile response when the
-- legacy profile keeps the unique email value and cannot duplicate it.
CREATE OR REPLACE FUNCTION public.current_user_profile()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  auth_id UUID := auth.uid();
  legacy_id UUID;
  linked_email TEXT;
  auth_profile public.profiles%ROWTYPE;
  legacy_profile public.profiles%ROWTYPE;
BEGIN
  IF auth_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT l.legacy_user_id, l.email
  INTO legacy_id, linked_email
  FROM public.legacy_auth_identity_links AS l
  WHERE l.auth_user_id = auth_id;
  legacy_id := COALESCE(legacy_id, auth_id);

  SELECT * INTO auth_profile FROM public.profiles WHERE id = auth_id;
  SELECT * INTO legacy_profile FROM public.profiles WHERE id = legacy_id;
  IF auth_profile.id IS NULL AND legacy_profile.id IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'id', auth_id,
    'legacy_user_id', legacy_id,
    'email', COALESCE(
      NULLIF(btrim(auth_profile.email), ''),
      NULLIF(btrim(legacy_profile.email), ''),
      NULLIF(btrim(linked_email), '')
    ),
    'full_name', COALESCE(
      NULLIF(btrim(auth_profile.full_name), ''),
      NULLIF(btrim(legacy_profile.full_name), ''),
      ''
    ),
    'phone_number', COALESCE(
      NULLIF(btrim(auth_profile.phone_number), ''),
      NULLIF(btrim(legacy_profile.phone_number), '')
    ),
    'photo_url', COALESCE(
      NULLIF(btrim(auth_profile.photo_url), ''),
      NULLIF(btrim(legacy_profile.photo_url), '')
    ),
    'address', COALESCE(
      NULLIF(btrim(auth_profile.address), ''),
      NULLIF(btrim(legacy_profile.address), '')
    ),
    'job_title', COALESCE(
      NULLIF(btrim(auth_profile.job_title), ''),
      NULLIF(btrim(legacy_profile.job_title), '')
    ),
    'pin', COALESCE(auth_profile.pin, legacy_profile.pin),
    'current_business_id', COALESCE(
      auth_profile.current_business_id,
      legacy_profile.current_business_id
    ),
    'created_at', COALESCE(auth_profile.created_at, legacy_profile.created_at),
    'updated_at', COALESCE(auth_profile.updated_at, legacy_profile.updated_at),
    'is_active', COALESCE(legacy_profile.is_active, auth_profile.is_active, true),
    'is_deleted', COALESCE(legacy_profile.is_deleted, auth_profile.is_deleted, false),
    'deleted_at', COALESCE(legacy_profile.deleted_at, auth_profile.deleted_at),
    'recovery_deadline_at', COALESCE(
      legacy_profile.recovery_deadline_at,
      auth_profile.recovery_deadline_at
    ),
    'deleted_by_id', COALESCE(legacy_profile.deleted_by_id, auth_profile.deleted_by_id),
    'deletion_reason', COALESCE(legacy_profile.deletion_reason, auth_profile.deletion_reason)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.current_user_profile() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_profile() TO managecare;
NOTIFY pgrst, 'reload schema';

COMMIT;
