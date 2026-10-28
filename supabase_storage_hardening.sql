-- =============================================================================
-- FlexiTap Phase 4: Supabase Storage Bucket Hardening & Tenant Isolation
-- Secures the 'backups' bucket, disallows public downloads, and restricts
-- cloud .bak database snapshots strictly to authenticated tenant owners/staff.
-- =============================================================================

-- 1. Ensure the 'backups' bucket exists and is strictly PRIVATE (public = false)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'backups', 
  'backups', 
  false, 
  104857600, -- 100 MB max file size
  ARRAY['application/octet-stream', 'application/x-gzip', 'application/gzip', 'application/x-sqlite3']
)
ON CONFLICT (id) DO UPDATE 
SET public = false;

-- 2. Ensure Row Level Security is active on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 3. Define the tenant-scoped backup security gate function
CREATE OR REPLACE FUNCTION public.can_access_backup_object(p_object_name text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_folder text;
  v_uid text := auth.uid()::text;
  v_is_admin boolean;
BEGIN
  -- Unauthenticated requests are completely rejected
  IF v_uid IS NULL THEN
    RETURN false;
  END IF;

  -- Allow Supabase service_role or admin operators
  v_is_admin := (
    coalesce(auth.jwt()->'app_metadata'->>'role', '') IN ('admin', 'service_role')
    OR coalesce(auth.jwt()->'user_metadata'->>'role', '') IN ('admin', 'developer')
  );
  IF v_is_admin THEN
    RETURN true;
  END IF;

  -- Extract the root folder from the storage path (e.g., 'store_id/store_id_date.bak' -> 'store_id')
  v_folder := (storage.foldername(p_object_name))[1];
  IF v_folder IS NULL OR v_folder = '' THEN
    RETURN false;
  END IF;

  -- Case A: The folder directly matches the authenticated user ID
  IF v_folder = v_uid THEN
    RETURN true;
  END IF;

  -- Case B: The folder matches the store_id in the user's profile
  IF EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id::text = v_uid AND store_id::text = v_folder
  ) THEN
    RETURN true;
  END IF;

  -- Case C: The folder matches a store where the user is recorded as owner or admin
  IF EXISTS (
    SELECT 1 FROM public.stores
    WHERE id::text = v_folder 
      AND (
        (owner_id::text = v_uid) 
        OR (user_id::text = v_uid)
      )
  ) THEN
    RETURN true;
  END IF;

  -- Case D: The folder matches a store device registered under this user
  IF EXISTS (
    SELECT 1 FROM public.devices
    WHERE store_id::text = v_folder AND user_id::text = v_uid
  ) THEN
    RETURN true;
  END IF;

  RETURN false;
EXCEPTION
  WHEN OTHERS THEN
    RETURN false;
END;
$$;

-- Grant execution permission to authenticated users
GRANT EXECUTE ON FUNCTION public.can_access_backup_object(text) TO authenticated;

-- 4. Clean up prior policies on storage.objects for 'backups' bucket
DROP POLICY IF EXISTS "Merchants can read own store backups" ON storage.objects;
DROP POLICY IF EXISTS "Merchants can upload own store backups" ON storage.objects;
DROP POLICY IF EXISTS "Merchants can update own store backups" ON storage.objects;
DROP POLICY IF EXISTS "Merchants can delete own store backups" ON storage.objects;

-- 5. Create secure tenant-isolated storage RLS policies

-- SELECT: Authenticated merchants can only view and download backups in their own folder
CREATE POLICY "Merchants can read own store backups"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'backups' 
  AND public.can_access_backup_object(name)
);

-- INSERT: Authenticated merchants can only upload backups into their own store folder
CREATE POLICY "Merchants can upload own store backups"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'backups' 
  AND public.can_access_backup_object(name)
);

-- UPDATE: Authenticated merchants can only overwrite/upsert backups in their own store folder
CREATE POLICY "Merchants can update own store backups"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'backups' 
  AND public.can_access_backup_object(name)
)
WITH CHECK (
  bucket_id = 'backups' 
  AND public.can_access_backup_object(name)
);

-- DELETE: Authenticated merchants can prune old backup rotations within their own store folder
CREATE POLICY "Merchants can delete own store backups"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'backups' 
  AND public.can_access_backup_object(name)
);

-- Verify bucket security status
SELECT id, name, public, file_size_limit, allowed_mime_types 
FROM storage.buckets 
WHERE id = 'backups';
