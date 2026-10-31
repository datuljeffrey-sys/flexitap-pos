-- =============================================================================
-- Migration 01: Core Profiles, Stores, Devices & Reporting Schema
-- Version: 20261031000001
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    store_name TEXT,
    phone TEXT,
    currency TEXT DEFAULT 'USD',
    role TEXT DEFAULT 'merchant',
    account_status TEXT DEFAULT 'active',
    deletion_requested_at TIMESTAMPTZ,
    deletion_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.stores (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    legal_name TEXT,
    contact_email TEXT,
    phone TEXT,
    currency TEXT DEFAULT 'USD',
    tax_rate NUMERIC DEFAULT 12.0,
    address TEXT,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.devices (
    id TEXT PRIMARY KEY,
    store_id TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'terminal',
    ip_address TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_seen TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.daily_sales_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id TEXT NOT NULL,
    date DATE NOT NULL,
    net_sales NUMERIC DEFAULT 0,
    gross_sales NUMERIC DEFAULT 0,
    transactions INTEGER DEFAULT 0,
    average_sale NUMERIC DEFAULT 0,
    total_discounts NUMERIC DEFAULT 0,
    total_refunds NUMERIC DEFAULT 0,
    total_taxes NUMERIC DEFAULT 0,
    tips NUMERIC DEFAULT 0,
    total_tendered NUMERIC DEFAULT 0,
    voided_count INTEGER DEFAULT 0,
    voided_amount NUMERIC DEFAULT 0,
    payment_breakdown JSONB DEFAULT '{}'::jsonb,
    category_breakdown JSONB DEFAULT '{}'::jsonb,
    hourly_sales JSONB DEFAULT '{}'::jsonb,
    terminal_sales JSONB DEFAULT '[]'::jsonb,
    product_mix JSONB DEFAULT '[]'::jsonb,
    labor_summary JSONB DEFAULT '[]'::jsonb,
    inventory_snapshot JSONB DEFAULT '[]'::jsonb,
    audit_exceptions JSONB DEFAULT '[]'::jsonb,
    customers_crm JSONB DEFAULT '[]'::jsonb,
    recent_checks JSONB DEFAULT '[]'::jsonb,
    discounts_summary JSONB DEFAULT '[]'::jsonb,
    gift_cards_summary JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_stores_owner_id ON public.stores(owner_id);
CREATE INDEX IF NOT EXISTS idx_stores_user_id ON public.stores(user_id);
CREATE INDEX IF NOT EXISTS idx_devices_store_id ON public.devices(store_id);
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON public.devices(user_id);
CREATE INDEX IF NOT EXISTS idx_devices_is_active ON public.devices(is_active);
CREATE INDEX IF NOT EXISTS idx_daily_sales_store_id ON public.daily_sales_summaries(store_id);
CREATE INDEX IF NOT EXISTS idx_daily_sales_date ON public.daily_sales_summaries(date);
CREATE INDEX IF NOT EXISTS idx_daily_sales_store_date ON public.daily_sales_summaries(store_id, date);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_sales_summaries ENABLE ROW LEVEL SECURITY;
