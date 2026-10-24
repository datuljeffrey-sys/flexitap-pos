-- ==============================================================================
-- FlexiTap POS & Dev Portal: Merchant In-App Feedback & Feature Request System
-- Migration: merchant_feedback Table, Indexes & RLS Policies
-- ==============================================================================

-- 1. Create merchant_feedback table
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

-- 2. Performance indexes for triage & search
CREATE INDEX IF NOT EXISTS idx_merchant_feedback_status 
  ON public.merchant_feedback(status);

CREATE INDEX IF NOT EXISTS idx_merchant_feedback_category 
  ON public.merchant_feedback(category);

CREATE INDEX IF NOT EXISTS idx_merchant_feedback_rating 
  ON public.merchant_feedback(rating);

CREATE INDEX IF NOT EXISTS idx_merchant_feedback_store_id 
  ON public.merchant_feedback(store_id);

CREATE INDEX IF NOT EXISTS idx_merchant_feedback_created_at 
  ON public.merchant_feedback(created_at DESC);

-- 3. Row Level Security (RLS)
ALTER TABLE public.merchant_feedback ENABLE ROW LEVEL SECURITY;

-- Allow insert by POS clients & Merchant Portal
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'merchant_feedback' AND policyname = 'Allow insert merchant_feedback'
  ) THEN
    CREATE POLICY "Allow insert merchant_feedback"
      ON public.merchant_feedback
      FOR INSERT
      WITH CHECK (true);
  END IF;
END $$;

-- Allow reading feedback records for Dev Console & Analytics
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'merchant_feedback' AND policyname = 'Allow select merchant_feedback'
  ) THEN
    CREATE POLICY "Allow select merchant_feedback"
      ON public.merchant_feedback
      FOR SELECT
      USING (true);
  END IF;
END $$;

-- Allow update by Dev Portal (status changes, dev notes)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'merchant_feedback' AND policyname = 'Allow update merchant_feedback'
  ) THEN
    CREATE POLICY "Allow update merchant_feedback"
      ON public.merchant_feedback
      FOR UPDATE
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;
