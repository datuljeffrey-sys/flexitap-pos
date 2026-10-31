-- =============================================================================
-- Migration 05: Usage Metering Ledger & Automated 30-Day Data Erasure Routine
-- Version: 20261031000005
-- Enforces Privacy Policy Clause 6 automated purges & consumable usage logging
-- =============================================================================

-- 1. Create Tenant Usage Metering Table
CREATE TABLE IF NOT EXISTS public.tenant_usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id TEXT NOT NULL,
    metric_name TEXT NOT NULL, -- 'api_sync_call', 'storage_bytes', 'active_seats', 'ai_forecast_call'
    quantity INTEGER NOT NULL DEFAULT 1,
    metadata JSONB DEFAULT '{}'::jsonb,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_usage_tenant_id ON public.tenant_usage_records(tenant_id);
CREATE INDEX IF NOT EXISTS idx_usage_metric_name ON public.tenant_usage_records(metric_name);
CREATE INDEX IF NOT EXISTS idx_usage_recorded_at ON public.tenant_usage_records(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_usage_tenant_metric ON public.tenant_usage_records(tenant_id, metric_name, recorded_at);

ALTER TABLE public.tenant_usage_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Merchants can read own usage records"
  ON public.tenant_usage_records
  FOR SELECT
  TO authenticated
  USING (
    tenant_id::text = auth.uid()::text
    OR tenant_id::text IN (
      SELECT id::text FROM public.stores 
      WHERE owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin')
    )
  );

CREATE POLICY "Service Role can insert usage records"
  ON public.tenant_usage_records
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- 2. Stored Procedure for Recording Usage Metering
CREATE OR REPLACE FUNCTION public.record_tenant_usage(
    p_tenant_id TEXT,
    p_metric_name TEXT,
    p_quantity INTEGER DEFAULT 1,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_record_id UUID;
BEGIN
    INSERT INTO public.tenant_usage_records (tenant_id, metric_name, quantity, metadata)
    VALUES (p_tenant_id, p_metric_name, p_quantity, p_metadata)
    RETURNING id INTO v_record_id;

    RETURN v_record_id;
END;
$function$;

-- 3. Stored Procedure: Automated 30-Day Data Erasure Routine (Privacy Clause 6)
-- Permanently purges operational records for accounts that exceeded the 30-day statutory cool-down
CREATE OR REPLACE FUNCTION public.purge_expired_deletion_accounts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    r RECORD;
    v_purged_count INTEGER := 0;
    v_stores_purged INTEGER := 0;
    v_sales_purged INTEGER := 0;
    v_devices_purged INTEGER := 0;
BEGIN
    -- Find all profiles where account_status is pending_deletion and grace period expired (30 days)
    FOR r IN
        SELECT id, email, deletion_requested_at
        FROM public.profiles
        WHERE account_status = 'pending_deletion'
          AND deletion_requested_at IS NOT NULL
          AND deletion_requested_at < (now() - INTERVAL '30 days')
    LOOP
        -- A. Purge Daily Sales Summaries associated with the merchant's stores
        WITH deleted_sales AS (
            DELETE FROM public.daily_sales_summaries
            WHERE store_id IN (
                SELECT id::text FROM public.stores 
                WHERE owner_id::text = r.id::text OR user_id::text = r.id::text
            ) OR store_id::text = r.id::text
            RETURNING id
        )
        SELECT v_sales_purged + count(*) INTO v_sales_purged FROM deleted_sales;

        -- B. Purge Registered Hardware Devices
        WITH deleted_devices AS (
            DELETE FROM public.devices
            WHERE user_id::text = r.id::text
               OR store_id IN (
                   SELECT id::text FROM public.stores 
                   WHERE owner_id::text = r.id::text OR user_id::text = r.id::text
               )
            RETURNING id
        )
        SELECT v_devices_purged + count(*) INTO v_devices_purged FROM deleted_devices;

        -- C. Purge Merchant Feedback
        DELETE FROM public.merchant_feedback
        WHERE store_id IN (
            SELECT id::text FROM public.stores 
            WHERE owner_id::text = r.id::text OR user_id::text = r.id::text
        ) OR lower(merchant_email) = lower(r.email);

        -- D. Purge Stores
        WITH deleted_stores AS (
            DELETE FROM public.stores
            WHERE owner_id::text = r.id::text OR user_id::text = r.id::text
            RETURNING id
        )
        SELECT v_stores_purged + count(*) INTO v_stores_purged FROM deleted_stores;

        -- E. Mark profile as permanently purged / delete profile record
        UPDATE public.profiles
        SET account_status = 'purged',
            email = 'purged_' || r.id || '@deleted.flexitap.app',
            full_name = 'Purged Account',
            store_name = 'Purged Store',
            phone = NULL,
            updated_at = now()
        WHERE id = r.id;

        v_purged_count := v_purged_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'purged_merchants', v_purged_count,
        'purged_stores', v_stores_purged,
        'purged_sales_summaries', v_sales_purged,
        'purged_devices', v_devices_purged,
        'executed_at', now()
    );
END;
$function$;
