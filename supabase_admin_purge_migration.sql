-- ==============================================================================
-- FLEXITAP ADMIN MERCHANT PURGE & GDPR/CCPA RIGHT-TO-ERASURE ENGINE
-- Enables permanent backend deletion/anonymization of merchant accounts from Dev Portal
-- ==============================================================================

-- 1. Helper function: verify if caller is an authorized Core Dev / Admin / Staff
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
        OR LOWER(COALESCE(auth.jwt() ->> 'email', '')) IN ('info@flexitapapp.com', 'datuljeffrey@gmail.com')
      )
  );
$$;

-- 2. SECURITY DEFINER RPC: Immediately and permanently purge a merchant account
CREATE OR REPLACE FUNCTION public.admin_purge_merchant_account(target_account_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_codes TEXT[];
  v_purged_sales INT := 0;
  v_purged_devices INT := 0;
  v_purged_stores INT := 0;
  v_is_authorized BOOLEAN := false;
BEGIN
  -- Security check: Must be authenticated and have dev/admin privileges
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required to purge accounts.';
  END IF;

  v_is_authorized := public.is_admin_or_staff_caller();
  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Access Denied: Only Core Dev / System Administrators can purge accounts.';
  END IF;

  -- Collect all store IDs associated with this merchant profile
  SELECT ARRAY_AGG(id::text) INTO v_store_codes
  FROM public.stores
  WHERE owner_id::text = target_account_id::text 
     OR user_id::text = target_account_id::text;

  -- A. Purge Daily Sales Summaries
  WITH del_sales AS (
    DELETE FROM public.daily_sales_summaries
    WHERE store_id::text = target_account_id::text
       OR (v_store_codes IS NOT NULL AND store_id::text = ANY(v_store_codes))
    RETURNING id
  )
  SELECT count(*) INTO v_purged_sales FROM del_sales;

  -- B. Purge Hardware Devices
  WITH del_devices AS (
    DELETE FROM public.devices
    WHERE user_id::text = target_account_id::text
       OR (v_store_codes IS NOT NULL AND store_id::text = ANY(v_store_codes))
    RETURNING id
  )
  SELECT count(*) INTO v_purged_devices FROM del_devices;

  -- C. Purge Merchant Feedback
  DELETE FROM public.merchant_feedback
  WHERE store_id::text = target_account_id::text
     OR (v_store_codes IS NOT NULL AND store_id::text = ANY(v_store_codes));

  -- D. Purge Merchant CRM Tables (if created)
  IF to_regclass('public.merchant_crm_assets') IS NOT NULL THEN
    DELETE FROM public.merchant_crm_assets WHERE account_id::text = target_account_id::text;
  END IF;
  IF to_regclass('public.merchant_crm_contacts') IS NOT NULL THEN
    DELETE FROM public.merchant_crm_contacts WHERE account_id::text = target_account_id::text;
  END IF;
  IF to_regclass('public.merchant_crm_accounts') IS NOT NULL THEN
    DELETE FROM public.merchant_crm_accounts WHERE id::text = target_account_id::text;
  END IF;

  -- E. Purge Stores
  WITH del_stores AS (
    DELETE FROM public.stores
    WHERE owner_id::text = target_account_id::text 
       OR user_id::text = target_account_id::text
    RETURNING id
  )
  SELECT count(*) INTO v_purged_stores FROM del_stores;

  -- F. Update and Anonymize Profile (marking purged status)
  UPDATE public.profiles
  SET account_status = 'purged',
      deletion_requested_at = now(),
      full_name = '[PURGED MERCHANT]',
      store_name = '[PURGED STORE]',
      email = 'purged_' || substr(target_account_id::text, 1, 8) || '@purged.local',
      phone = NULL,
      updated_at = now()
  WHERE id = target_account_id;

  -- G. Attempt hard delete of profile row (if no dangling constraints)
  BEGIN
    DELETE FROM public.profiles WHERE id = target_account_id;
  EXCEPTION WHEN OTHERS THEN
    -- If foreign key prevents hard delete, soft-delete with 'purged' remains intact
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'purged_account_id', target_account_id,
    'purged_stores', v_purged_stores,
    'purged_devices', v_purged_devices,
    'purged_sales', v_purged_sales,
    'purged_at', now()
  );
END;
$$;

-- 3. RLS HARDENING: Explicitly allow Staff to DELETE & UPDATE profiles and stores
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff can delete profiles" ON public.profiles;
CREATE POLICY "Staff can delete profiles"
  ON public.profiles FOR DELETE
  TO authenticated
  USING (public.is_admin_or_staff_caller());

DROP POLICY IF EXISTS "Staff can update any profile" ON public.profiles;
CREATE POLICY "Staff can update any profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (public.is_admin_or_staff_caller() OR auth.uid() = id);

DROP POLICY IF EXISTS "Staff can delete stores" ON public.stores;
CREATE POLICY "Staff can delete stores"
  ON public.stores FOR DELETE
  TO authenticated
  USING (public.is_admin_or_staff_caller());

DROP POLICY IF EXISTS "Staff can manage all stores" ON public.stores;
CREATE POLICY "Staff can manage all stores"
  ON public.stores FOR ALL
  TO authenticated
  USING (public.is_admin_or_staff_caller() OR owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text);
