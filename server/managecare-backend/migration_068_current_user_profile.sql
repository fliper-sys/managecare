BEGIN;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS job_title TEXT;

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
  auth_profile public.profiles%ROWTYPE;
  legacy_profile public.profiles%ROWTYPE;
BEGIN
  IF auth_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT l.legacy_user_id INTO legacy_id
  FROM public.legacy_auth_identity_links l
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
    'email', COALESCE(NULLIF(trim(auth_profile.email), ''), NULLIF(trim(legacy_profile.email), '')),
    'full_name', COALESCE(NULLIF(trim(auth_profile.full_name), ''), NULLIF(trim(legacy_profile.full_name), ''), ''),
    'phone_number', COALESCE(NULLIF(trim(auth_profile.phone_number), ''), NULLIF(trim(legacy_profile.phone_number), '')),
    'photo_url', COALESCE(NULLIF(trim(auth_profile.photo_url), ''), NULLIF(trim(legacy_profile.photo_url), '')),
    'address', COALESCE(NULLIF(trim(auth_profile.address), ''), NULLIF(trim(legacy_profile.address), '')),
    'job_title', COALESCE(NULLIF(trim(auth_profile.job_title), ''), NULLIF(trim(legacy_profile.job_title), '')),
    'pin', COALESCE(auth_profile.pin, legacy_profile.pin),
    'current_business_id', COALESCE(auth_profile.current_business_id, legacy_profile.current_business_id),
    'created_at', COALESCE(auth_profile.created_at, legacy_profile.created_at),
    'updated_at', COALESCE(auth_profile.updated_at, legacy_profile.updated_at),
    'is_active', COALESCE(legacy_profile.is_active, auth_profile.is_active, true),
    'is_deleted', COALESCE(legacy_profile.is_deleted, auth_profile.is_deleted, false),
    'deleted_at', COALESCE(legacy_profile.deleted_at, auth_profile.deleted_at),
    'recovery_deadline_at', COALESCE(legacy_profile.recovery_deadline_at, auth_profile.recovery_deadline_at),
    'deleted_by_id', COALESCE(legacy_profile.deleted_by_id, auth_profile.deleted_by_id),
    'deletion_reason', COALESCE(legacy_profile.deletion_reason, auth_profile.deletion_reason)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.current_user_profile() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_profile() TO managecare;

NOTIFY pgrst, 'reload schema';

COMMIT;
