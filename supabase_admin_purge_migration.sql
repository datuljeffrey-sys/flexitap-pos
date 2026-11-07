-- ==============================================================================
-- FLEXITAP COMPLETE MERCHANT DELETION ENGINE (100% TOTAL HARD PURGE)
-- Permanently wipes records from:
--   1. auth.users (Supabase Master Auth)
--   2. public.profiles
--   3. public.stores
--   4. public.subscriptions
--   5. public.devices & pos_devices
--   6. public.tickets & ticket_notes
--   7. public.support_messages & support_sessions
--   8. public.remote_support_sessions, remote_control_queue & remote_commands
--   9. public.merchant_feedback & daily_sales_summaries
-- ==============================================================================

-- 1. Helper function: verify caller authority
CREATE OR REPLACE FUNCTION public.is_admin_or_staff_caller()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
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

-- 2. SECURITY DEFINER RPC: Permanently wipes a merchant and all cascading records
CREATE OR REPLACE FUNCTION public.admin_purge_merchant_account(target_account_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_store_ids TEXT[];
  v_is_authorized BOOLEAN := false;
  v_purged_stores INT := 0;
  v_purged_devices INT := 0;
  v_purged_subscriptions INT := 0;
BEGIN
  -- Security check: Caller must be authenticated admin or staff
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required to purge accounts.';
  END IF;

  v_is_authorized := public.is_admin_or_staff_caller();
  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Access Denied: Only Core Dev / System Administrators can purge merchant accounts.';
  END IF;

  -- Collect all store IDs associated with this merchant profile
  SELECT ARRAY_AGG(id::text) INTO v_store_ids
  FROM public.stores
  WHERE owner_id::text = target_account_id::text 
     OR user_id::text = target_account_id::text;

  -- 1. Wipe subscriptions
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

  -- 4. Wipe tickets & ticket notes
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

  -- 8. TOTAL HARD DELETION: Wipe from public.profiles
  DELETE FROM public.profiles WHERE id = target_account_id;

  -- 9. TOTAL HARD DELETION: Wipe from auth.users (Master Supabase Auth)
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

-- 3. RLS Policies allowing Staff full deletion authority
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff can delete profiles" ON public.profiles;
CREATE POLICY "Staff can delete profiles"
  ON public.profiles FOR DELETE
  TO authenticated
  USING (public.is_admin_or_staff_caller());

DROP POLICY IF EXISTS "Staff can delete stores" ON public.stores;
CREATE POLICY "Staff can delete stores"
  ON public.stores FOR DELETE
  TO authenticated
  USING (public.is_admin_or_staff_caller());

DROP POLICY IF EXISTS "Staff can delete subscriptions" ON public.subscriptions;
CREATE POLICY "Staff can delete subscriptions"
  ON public.subscriptions FOR DELETE
  TO authenticated
  USING (public.is_admin_or_staff_caller());
