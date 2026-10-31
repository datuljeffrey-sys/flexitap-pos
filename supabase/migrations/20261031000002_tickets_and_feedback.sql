-- =============================================================================
-- Migration 02: Tickets CRM, Internal Notes & Merchant Feedback
-- Version: 20261031000002
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number TEXT NOT NULL,
    merchant_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    store_name TEXT NOT NULL,
    contact_email TEXT,
    subject TEXT NOT NULL,
    details TEXT,
    category TEXT NOT NULL DEFAULT 'general',
    priority TEXT NOT NULL DEFAULT 'medium',
    status TEXT NOT NULL DEFAULT 'open',
    tier TEXT DEFAULT 'tier_1',
    assigned_to TEXT,
    resolution_notes TEXT,
    device_telemetry JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    resolved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.ticket_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
    author_email TEXT NOT NULL,
    note TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.merchant_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id TEXT,
    store_name TEXT NOT NULL,
    merchant_email TEXT,
    category TEXT NOT NULL CHECK (category IN ('feature_request', 'ux_improvement', 'bug', 'general_feedback')),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    impact_level TEXT DEFAULT 'important' CHECK (impact_level IN ('nice_to_have', 'important', 'critical')),
    app_version TEXT,
    platform TEXT,
    device_role TEXT,
    status TEXT DEFAULT 'new' CHECK (status IN ('new', 'under_review', 'planned', 'in_progress', 'shipped', 'declined')),
    dev_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tickets_merchant_id ON public.tickets(merchant_id);
CREATE INDEX IF NOT EXISTS idx_tickets_store_name ON public.tickets(store_name);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON public.tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_created_at ON public.tickets(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ticket_notes_ticket_id ON public.ticket_notes(ticket_id);
CREATE INDEX IF NOT EXISTS idx_merchant_feedback_store_id ON public.merchant_feedback(store_id);
CREATE INDEX IF NOT EXISTS idx_merchant_feedback_status ON public.merchant_feedback(status);
CREATE INDEX IF NOT EXISTS idx_merchant_feedback_created_at ON public.merchant_feedback(created_at DESC);

-- Enable RLS
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_feedback ENABLE ROW LEVEL SECURITY;
