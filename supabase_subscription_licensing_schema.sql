-- =============================================================================
-- FlexiTap v2: Canonical Subscription, Licensing & Device Slot Migration
-- Single Source of Truth for Store Licensing, Device Quotas & Paddle Webhooks
-- =============================================================================

-- 1. Ensure columns exist on public.profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_tier text NOT NULL DEFAULT 'free';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS pending_tier text DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS payment_status text NOT NULL DEFAULT 'free';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_valid_until timestamptz DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_expires_at timestamptz DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS billing_provider text DEFAULT 'paddle';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_account_suspended boolean NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS suspension_reason text DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS max_devices_override integer DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS paddle_customer_id text DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS paddle_subscription_id text DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS paddle_transaction_id text DEFAULT NULL;

-- 2. Ensure columns exist on public.stores
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS subscription_tier text NOT NULL DEFAULT 'free';
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS payment_status text NOT NULL DEFAULT 'free';
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS max_devices integer NOT NULL DEFAULT 1;
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS subscription_expires_at timestamptz DEFAULT NULL;
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS billing_provider text DEFAULT 'paddle';
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS is_account_suspended boolean NOT NULL DEFAULT false;
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS suspension_reason text DEFAULT NULL;

-- 3. Ensure public.devices table exists with proper indexes
CREATE TABLE IF NOT EXISTS public.devices (
  id text PRIMARY KEY,
  store_id text NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  name text NOT NULL,
  role text NOT NULL DEFAULT 'terminal',
  ip_address text,
  is_active boolean NOT NULL DEFAULT true,
  last_seen timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_devices_store_id ON public.devices(store_id);
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON public.devices(user_id);
CREATE INDEX IF NOT EXISTS idx_devices_is_active ON public.devices(is_active);

-- Enable RLS on devices
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

-- Devices RLS: Authenticated users can view devices for their own stores
DROP POLICY IF EXISTS "Merchants can read own store devices" ON public.devices;
CREATE POLICY "Merchants can read own store devices"
ON public.devices FOR SELECT
TO authenticated
USING (
  user_id::text = auth.uid()::text
  OR store_id::text IN (
    SELECT id::text FROM public.stores 
    WHERE (owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text)
  )
);

-- Devices RLS: Authenticated users can register/update their own store devices
DROP POLICY IF EXISTS "Merchants can upsert own store devices" ON public.devices;
CREATE POLICY "Merchants can upsert own store devices"
ON public.devices FOR ALL
TO authenticated
USING (
  user_id::text = auth.uid()::text
  OR store_id::text IN (
    SELECT id::text FROM public.stores 
    WHERE (owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text)
  )
)
WITH CHECK (
  user_id::text = auth.uid()::text
  OR store_id::text IN (
    SELECT id::text FROM public.stores 
    WHERE (owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text)
  )
);

-- 4. Secure RPC for Deactivating / Disconnecting a Device Slot
CREATE OR REPLACE FUNCTION public.deactivate_store_device(p_device_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_store_id text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Verify device belongs to this user or their store (handling uuid or text columns)
  SELECT store_id::text INTO v_store_id
  FROM public.devices
  WHERE id::text = p_device_id::text
    AND (
      user_id::text = v_user_id::text
      OR store_id::text IN (
        SELECT id::text FROM public.stores 
        WHERE (owner_id::text = v_user_id::text OR user_id::text = v_user_id::text)
      )
    );

  IF v_store_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Device not found or permission denied');
  END IF;

  -- Deactivate the device slot
  UPDATE public.devices
  SET is_active = false,
      last_seen = now()
  WHERE id::text = p_device_id::text;

  RETURN jsonb_build_object('success', true, 'device_id', p_device_id);
END;
$function$;

-- 5. Secure RPC for Admin / Dev Portal Overriding Merchant Subscription
CREATE OR REPLACE FUNCTION public.admin_set_merchant_subscription(
  p_target_user_id uuid,
  p_tier text,
  p_payment_status text DEFAULT 'paid',
  p_valid_until timestamptz DEFAULT NULL,
  p_max_devices_override integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_max_devices integer;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Check if caller is dev or admin
  SELECT role INTO v_caller_role FROM public.profiles WHERE id::text = v_caller_id::text;
  IF v_caller_role NOT IN ('dev', 'developer', 'admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Forbidden: Admin access required');
  END IF;

  -- Calculate max devices based on tier
  IF p_max_devices_override IS NOT NULL THEN
    v_max_devices := p_max_devices_override;
  ELSIF p_tier = 'pro' THEN
    v_max_devices := 9999;
  ELSIF p_tier = 'plus' THEN
    v_max_devices := 10;
  ELSE
    v_max_devices := 1;
  END IF;

  -- Update profiles
  UPDATE public.profiles
  SET subscription_tier = p_tier,
      payment_status = p_payment_status,
      subscription_valid_until = p_valid_until,
      max_devices_override = p_max_devices_override
  WHERE id::text = p_target_user_id::text;

  -- Sync stores table
  UPDATE public.stores
  SET subscription_tier = p_tier,
      payment_status = p_payment_status,
      max_devices = v_max_devices
  WHERE owner_id::text = p_target_user_id::text OR user_id::text = p_target_user_id::text;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', p_target_user_id,
    'tier', p_tier,
    'max_devices', v_max_devices
  );
END;
$function$;
