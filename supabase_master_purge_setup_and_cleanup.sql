-- ==============================================================================
-- FLEXITAP SUPABASE MASTER PURGE ENGINE & ASSET MANAGEMENT CLEANUP
-- ==============================================================================
-- INSTRUCTIONS:
-- 1. Open your Supabase Dashboard: https://supabase.com/dashboard/project/_/sql
-- 2. Click "New Query" (or paste into SQL Editor).
-- 3. Click "RUN" (or Ctrl + Enter).
-- 
-- WHAT THIS SCRIPT DOES:
-- Part 1: Installs 'admin_purge_merchant_account' & 'admin_delete_hardware_asset' (SECURITY DEFINER)
--         Allows Dev Portal & Merchant Portal to permanently hard-purge accounts
--         and individual hardware assets/devices from Supabase.
-- Part 2: Sets up RLS DELETE policies so staff accounts can manage profiles, stores, subscriptions, and devices.
-- Part 3: Wipes all existing dummy/test merchant rows (test, fdfd, hjnj, KKK, etc.)
--         while strictly protecting master staff accounts (info@, datuljeffrey@, liamjareddatul@).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- PART 1: INSTALL CORE FUNCTIONS & SECURITY DEFINER ENGINE
-- ------------------------------------------------------------------------------

-- Helper function: Verify if caller is authorized staff/admin
CREATE OR REPLACE FUNCTION public.is_admin_or_staff_caller()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() 
      AND (
        LOWER(role) IN ('admin', 'super_admin', 'dev', 'developer', 'staff', 'owner', 'ops')
        OR LOWER(COALESCE(auth.jwt() ->> 'email', '')) IN (
          'info@flexitapapp.com', 
          'datuljeffrey@gmail.com', 
          'liamjareddatul@gmail.com'
        )
      )
  );
$$;

-- Master RPC Function: 100% Total Hard Deletion across all schemas
CREATE OR REPLACE FUNCTION public.admin_purge_merchant_account(target_account_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_store_ids TEXT[];
  v_is_authorized BOOLEAN := false;
  v_purged_stores INT := 0;
  v_purged_devices INT := 0;
  v_purged_subscriptions INT := 0;
BEGIN
  -- A. Authentication guard
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required to purge accounts.';
  END IF;

  -- B. Authorization guard: Dev/Staff OR self deletion
  v_is_authorized := (auth.uid() = target_account_id) OR public.is_admin_or_staff_caller();
  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Access Denied: You are not authorized to purge this merchant account.';
  END IF;

  -- C. Collect all store IDs associated with this merchant profile
  IF to_regclass('public.stores') IS NOT NULL THEN
    SELECT ARRAY_AGG(id::text) INTO v_store_ids
    FROM public.stores
    WHERE owner_id::text = target_account_id::text 
       OR user_id::text = target_account_id::text;
  END IF;

  -- 1. Wipe subscriptions (release FK constraint on profiles)
  IF to_regclass('public.subscriptions') IS NOT NULL THEN
    WITH del_subs AS (
      DELETE FROM public.subscriptions
      WHERE user_id::text = target_account_id::text
      RETURNING id
    )
    SELECT count(*) INTO v_purged_subscriptions FROM del_subs;
  END IF;

  -- 2. Wipe devices & pos_devices
  IF to_regclass('public.devices') IS NOT NULL THEN
    WITH del_dev AS (
      DELETE FROM public.devices
      WHERE user_id::text = target_account_id::text
         OR (v_store_ids IS NOT NULL AND store_id::text = ANY(v_store_ids))
      RETURNING id
    )
    SELECT count(*) INTO v_purged_devices FROM del_dev;
  END IF;

  IF to_regclass('public.pos_devices') IS NOT NULL THEN
    DELETE FROM public.pos_devices
    WHERE user_id::text = target_account_id::text
       OR (v_store_ids IS NOT NULL AND store_id::text = ANY(v_store_ids));
  END IF;

  -- 3. Wipe sales summaries & feedback
  IF to_regclass('public.daily_sales_summaries') IS NOT NULL THEN
    DELETE FROM public.daily_sales_summaries
    WHERE store_id::text = target_account_id::text
       OR (v_store_ids IS NOT NULL AND store_id::text = ANY(v_store_ids));
  END IF;

  IF to_regclass('public.merchant_feedback') IS NOT NULL THEN
    DELETE FROM public.merchant_feedback
    WHERE store_id::text = target_account_id::text
       OR (v_store_ids IS NOT NULL AND store_id::text = ANY(v_store_ids));
  END IF;

  -- 4. Wipe tickets & notes
  IF to_regclass('public.ticket_notes') IS NOT NULL THEN
    DELETE FROM public.ticket_notes
    WHERE ticket_id IN (
      SELECT id FROM public.tickets 
      WHERE merchant_id::text = target_account_id::text
         OR (v_store_ids IS NOT NULL AND store_id::text = ANY(v_store_ids))
    );
  END IF;

  IF to_regclass('public.tickets') IS NOT NULL THEN
    DELETE FROM public.tickets
    WHERE merchant_id::text = target_account_id::text
       OR (v_store_ids IS NOT NULL AND store_id::text = ANY(v_store_ids));
  END IF;

  -- 5. Wipe support & remote sessions
  IF to_regclass('public.support_messages') IS NOT NULL THEN
    DELETE FROM public.support_messages WHERE sender_id::text = target_account_id::text;
  END IF;

  IF to_regclass('public.support_sessions') IS NOT NULL THEN
    DELETE FROM public.support_sessions WHERE user_id::text = target_account_id::text;
  END IF;

  IF to_regclass('public.remote_commands') IS NOT NULL THEN
    DELETE FROM public.remote_commands WHERE user_id::text = target_account_id::text;
  END IF;

  IF to_regclass('public.remote_control_queue') IS NOT NULL THEN
    DELETE FROM public.remote_control_queue WHERE user_id::text = target_account_id::text;
  END IF;

  IF to_regclass('public.remote_support_sessions') IS NOT NULL THEN
    DELETE FROM public.remote_support_sessions 
    WHERE merchant_user_id::text = target_account_id::text 
       OR staff_user_id::text = target_account_id::text;
  END IF;

  -- 6. Wipe CRM tables
  IF to_regclass('public.merchant_crm_assets') IS NOT NULL THEN
    DELETE FROM public.merchant_crm_assets WHERE account_id::text = target_account_id::text;
  END IF;
  IF to_regclass('public.merchant_crm_contacts') IS NOT NULL THEN
    DELETE FROM public.merchant_crm_contacts WHERE account_id::text = target_account_id::text;
  END IF;
  IF to_regclass('public.merchant_crm_accounts') IS NOT NULL THEN
    DELETE FROM public.merchant_crm_accounts WHERE id::text = target_account_id::text;
  END IF;

  -- 7. Wipe stores
  IF to_regclass('public.stores') IS NOT NULL THEN
    WITH del_st AS (
      DELETE FROM public.stores
      WHERE owner_id::text = target_account_id::text 
         OR user_id::text = target_account_id::text
         OR (v_store_ids IS NOT NULL AND id::text = ANY(v_store_ids))
      RETURNING id
    )
    SELECT count(*) INTO v_purged_stores FROM del_st;
  END IF;

  -- 8. Hard delete from profiles
  IF to_regclass('public.profiles') IS NOT NULL THEN
    DELETE FROM public.profiles WHERE id = target_account_id;
  END IF;

  -- 9. Hard delete from auth.users (Master Supabase Auth)
  DELETE FROM auth.users WHERE id = target_account_id;

  RETURN jsonb_build_object(
    'success', true,
    'purged_account_id', target_account_id,
    'purged_stores', v_purged_stores,
    'purged_devices', v_purged_devices,
    'purged_subscriptions', v_purged_subscriptions,
    'deleted_from_auth_users', true,
    'deleted_from_profiles', true,
    'timestamp', now()
  );
END;
$$;

-- Master RPC Function: 100% Total Permanent Deletion of a Hardware Device Asset
CREATE OR REPLACE FUNCTION public.admin_delete_hardware_asset(p_device_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_is_authorized boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required.');
  END IF;

  v_is_authorized := public.is_admin_or_staff_caller() OR EXISTS (
    SELECT 1 FROM public.devices d
    WHERE d.id::text = p_device_id::text
      AND (
        d.user_id::text = v_caller_id::text
        OR d.store_id::text IN (
          SELECT s.id::text FROM public.stores s
          WHERE s.owner_id::text = v_caller_id::text OR s.user_id::text = v_caller_id::text
        )
      )
  );

  IF NOT v_is_authorized THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized to delete this hardware device.');
  END IF;

  -- Hard delete from all device registries
  DELETE FROM public.devices WHERE id::text = p_device_id::text;
  IF to_regclass('public.pos_devices') IS NOT NULL THEN
    DELETE FROM public.pos_devices WHERE id::text = p_device_id::text;
  END IF;
  IF to_regclass('public.merchant_crm_assets') IS NOT NULL THEN
    DELETE FROM public.merchant_crm_assets WHERE id::text = p_device_id::text;
  END IF;

  RETURN jsonb_build_object('success', true, 'deleted_id', p_device_id);
END;
$$;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.is_admin_or_staff_caller() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_purge_merchant_account(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_hardware_asset(text) TO authenticated, anon;

-- ------------------------------------------------------------------------------
-- PART 2: RLS DELETE POLICIES (Enables direct deletes for authorized staff)
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff can delete profiles" ON public.profiles;
CREATE POLICY "Staff can delete profiles"
  ON public.profiles FOR DELETE
  TO authenticated
  USING (public.is_admin_or_staff_caller() OR auth.uid() = id);

DROP POLICY IF EXISTS "Staff can delete stores" ON public.stores;
CREATE POLICY "Staff can delete stores"
  ON public.stores FOR DELETE
  TO authenticated
  USING (public.is_admin_or_staff_caller() OR owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS "Staff can delete subscriptions" ON public.subscriptions;
CREATE POLICY "Staff can delete subscriptions"
  ON public.subscriptions FOR DELETE
  TO authenticated
  USING (public.is_admin_or_staff_caller() OR user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS "Staff and owners can delete devices" ON public.devices;
CREATE POLICY "Staff and owners can delete devices"
  ON public.devices FOR DELETE
  TO authenticated
  USING (
    public.is_admin_or_staff_caller()
    OR user_id::text = auth.uid()::text
    OR store_id::text IN (
      SELECT id::text FROM public.stores 
      WHERE (owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text)
    )
  );


-- ------------------------------------------------------------------------------
-- PART 3: IMMEDIATE ONE-TIME BATCH CLEANUP (Purges test / dummy rows right now)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_purge_ids UUID[];
  v_store_ids TEXT[];
  v_count INT := 0;
BEGIN
  -- Select all test/dummy account profile IDs (Excluding master admin/dev emails & stores)
  SELECT ARRAY_AGG(p.id) INTO v_purge_ids
  FROM public.profiles p
  LEFT JOIN auth.users u ON u.id = p.id
  WHERE (
    LOWER(COALESCE(p.store_name, '')) IN ('test', 'test account', 'fdfd', 'hjnj', 'kkk', 'flexitap', 'null')
    OR LOWER(COALESCE(p.full_name, '')) IN ('test', 'test account', 'purged merchant')
    OR LOWER(COALESCE(u.email, '')) LIKE '%test%'
    OR LOWER(COALESCE(u.email, '')) LIKE '%purged%'
    OR p.id IN (
      SELECT s.owner_id FROM public.stores s 
      WHERE LOWER(s.name) IN ('test', 'test account', 'fdfd', 'hjnj', 'kkk')
    )
  )
  -- NEVER delete real master admin/dev accounts or real business records
  AND LOWER(COALESCE(u.email, '')) NOT IN ('info@flexitapapp.com', 'datuljeffrey@gmail.com', 'liamjareddatul@gmail.com')
  AND LOWER(COALESCE(p.store_name, '')) NOT IN ('weed cafe', 'my cafe tarlac', 'info');

  v_count := COALESCE(array_length(v_purge_ids, 1), 0);
  RAISE NOTICE 'Found % dummy test accounts to permanently purge.', v_count;

  IF v_purge_ids IS NOT NULL AND v_count > 0 THEN
    -- Find all stores owned by these test accounts or named 'test', 'fdfd', 'kkk'
    SELECT ARRAY_AGG(id::text) INTO v_store_ids
    FROM public.stores
    WHERE owner_id = ANY(v_purge_ids)
       OR user_id = ANY(v_purge_ids)
       OR LOWER(name) IN ('test', 'test account', 'fdfd', 'hjnj', 'kkk');

    -- 1. Subscriptions
    IF to_regclass('public.subscriptions') IS NOT NULL THEN
      DELETE FROM public.subscriptions WHERE user_id = ANY(v_purge_ids);
    END IF;

    -- 2. Devices
    IF to_regclass('public.devices') IS NOT NULL THEN
      DELETE FROM public.devices 
      WHERE user_id = ANY(v_purge_ids)
         OR (v_store_ids IS NOT NULL AND store_id::text = ANY(v_store_ids));
    END IF;

    IF to_regclass('public.pos_devices') IS NOT NULL THEN
      DELETE FROM public.pos_devices 
      WHERE user_id = ANY(v_purge_ids)
         OR (v_store_ids IS NOT NULL AND store_id::text = ANY(v_store_ids));
    END IF;

    -- 3. Tickets
    IF to_regclass('public.tickets') IS NOT NULL THEN
      DELETE FROM public.tickets 
      WHERE merchant_id = ANY(v_purge_ids)
         OR (v_store_ids IS NOT NULL AND store_id::text = ANY(v_store_ids));
    END IF;

    -- 4. Stores
    IF to_regclass('public.stores') IS NOT NULL THEN
      DELETE FROM public.stores 
      WHERE owner_id = ANY(v_purge_ids)
         OR user_id = ANY(v_purge_ids)
         OR (v_store_ids IS NOT NULL AND id::text = ANY(v_store_ids));
    END IF;

    -- 5. Profiles
    DELETE FROM public.profiles WHERE id = ANY(v_purge_ids);

    -- 6. auth.users (Master Auth records)
    DELETE FROM auth.users WHERE id = ANY(v_purge_ids);

    RAISE NOTICE 'Successfully purged % test accounts from Supabase!', v_count;
  END IF;
END $$;
