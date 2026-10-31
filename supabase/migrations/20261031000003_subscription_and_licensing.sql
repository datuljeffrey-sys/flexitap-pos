-- =============================================================================
-- Migration 03: Subscription Licensing, Hardware Quotas & Paddle Integration
-- Version: 20261031000003
-- =============================================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_tier TEXT NOT NULL DEFAULT 'free';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'free';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_valid_until TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS billing_provider TEXT DEFAULT 'paddle';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_account_suspended BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS suspension_reason TEXT DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS max_devices_override INTEGER DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS paddle_customer_id TEXT DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS paddle_subscription_id TEXT DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS paddle_transaction_id TEXT DEFAULT NULL;

ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS subscription_tier TEXT NOT NULL DEFAULT 'free';
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'free';
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS max_devices INTEGER NOT NULL DEFAULT 1;
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS billing_provider TEXT DEFAULT 'paddle';
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS is_account_suspended BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS suspension_reason TEXT DEFAULT NULL;

-- Secure RPC for Deactivating Store Device Slot
CREATE OR REPLACE FUNCTION public.deactivate_store_device(p_device_id TEXT)
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

  UPDATE public.devices
  SET is_active = false,
      last_seen = now()
  WHERE id::text = p_device_id::text;

  RETURN jsonb_build_object('success', true, 'device_id', p_device_id);
END;
$function$;
