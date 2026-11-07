-- ==============================================================================
-- ONE-TIME CLEANUP SCRIPT: PURGE ALL DEAD TEST ACCOUNTS FROM SUPABASE
-- Run this in the Supabase SQL Editor to wipe test, fdfd, and orphaned test stores
-- ==============================================================================

DO $$
DECLARE
  r RECORD;
  v_test_user_ids UUID[];
  v_test_store_ids TEXT[];
BEGIN
  -- 1. Identify all test merchant user IDs from profiles and stores
  SELECT ARRAY_AGG(id) INTO v_test_user_ids
  FROM public.profiles
  WHERE LOWER(store_name) IN ('test', 'test account', 'fdfd', 'flexitap', 'null')
     OR LOWER(full_name) IN ('test', 'test account', 'purged merchant')
     OR LOWER(email) LIKE '%purged%'
     OR LOWER(email) LIKE '%test%';

  -- Collect store IDs named 'test'
  SELECT ARRAY_AGG(id::text) INTO v_test_store_ids
  FROM public.stores
  WHERE LOWER(name) IN ('test', 'test account', 'fdfd')
     OR (v_test_user_ids IS NOT NULL AND (owner_id = ANY(v_test_user_ids) OR user_id = ANY(v_test_user_ids)));

  RAISE NOTICE 'Found % test users to purge.', COALESCE(array_length(v_test_user_ids, 1), 0);

  -- 2. Delete test subscriptions
  IF to_regclass('public.subscriptions') IS NOT NULL AND v_test_user_ids IS NOT NULL THEN
    DELETE FROM public.subscriptions WHERE user_id = ANY(v_test_user_ids);
  END IF;

  -- 3. Delete test devices
  IF to_regclass('public.devices') IS NOT NULL THEN
    DELETE FROM public.devices 
    WHERE (v_test_user_ids IS NOT NULL AND user_id = ANY(v_test_user_ids))
       OR (v_test_store_ids IS NOT NULL AND store_id::text = ANY(v_test_store_ids));
  END IF;

  -- 4. Delete test stores
  IF to_regclass('public.stores') IS NOT NULL AND (v_test_store_ids IS NOT NULL OR v_test_user_ids IS NOT NULL) THEN
    DELETE FROM public.stores 
    WHERE (v_test_store_ids IS NOT NULL AND id::text = ANY(v_test_store_ids))
       OR (v_test_user_ids IS NOT NULL AND (owner_id = ANY(v_test_user_ids) OR user_id = ANY(v_test_user_ids)));
  END IF;

  -- 5. Delete test profiles
  IF v_test_user_ids IS NOT NULL THEN
    DELETE FROM public.profiles WHERE id = ANY(v_test_user_ids);
  END IF;

  -- 6. Delete test users from auth.users (Permanent complete hard deletion)
  IF v_test_user_ids IS NOT NULL THEN
    DELETE FROM auth.users WHERE id = ANY(v_test_user_ids);
  END IF;

  RAISE NOTICE 'Successfully purged test accounts from database!';
END $$;
