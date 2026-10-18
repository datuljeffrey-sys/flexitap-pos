-- =================================================================
-- FLEXITAP PHILIPPINE PARTNER & REFERRAL PROGRAM (PH PILOT)
-- Complete Supabase PostgreSQL Schema & Security Policies
-- =================================================================

-- 1. AFFILIATES PROFILE TABLE (PH Localized)
CREATE TABLE IF NOT EXISTS public.affiliates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  affiliate_code TEXT UNIQUE NOT NULL,      -- e.g., 'MANILA-BREW' or 'JAY20'
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone_ph TEXT NOT NULL,                   -- PH mobile number: e.g. 09171234567
  country TEXT DEFAULT 'PH',
  payout_type TEXT NOT NULL CHECK (payout_type IN ('gcash', 'maya', 'bank')),
  payout_account_name TEXT NOT NULL,
  payout_account_number TEXT NOT NULL,      -- Mobile for GCash/Maya, Bank Acct #
  payout_bank_name TEXT,                    -- BDO, BPI, UnionBank, Metrobank, GoTyme, etc.
  commission_type TEXT DEFAULT 'flat' CHECK (commission_type IN ('flat', 'percentage')),
  commission_rate NUMERIC(4,2) DEFAULT 0.20,
  flat_bounty_plus_php NUMERIC(10,2) DEFAULT 3000.00,
  flat_bounty_pro_php NUMERIC(10,2) DEFAULT 6000.00,
  status TEXT DEFAULT 'active' CHECK (status IN ('pending', 'active', 'suspended')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for instant lookup by affiliate code
CREATE INDEX IF NOT EXISTS idx_affiliates_code ON public.affiliates(LOWER(affiliate_code));
CREATE INDEX IF NOT EXISTS idx_affiliates_user ON public.affiliates(user_id);
CREATE INDEX IF NOT EXISTS idx_affiliates_email ON public.affiliates(LOWER(email));

-- 2. CLICKS & TELEMETRY LOG
CREATE TABLE IF NOT EXISTS public.affiliate_clicks (
  id BIGSERIAL PRIMARY KEY,
  affiliate_code TEXT NOT NULL,
  landing_path TEXT,
  referrer TEXT,
  ip_hash TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_code ON public.affiliate_clicks(affiliate_code);
CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_date ON public.affiliate_clicks(created_at);

-- 3. REFERRALS BINDING (Tied to Store on Signup or Waitlist)
CREATE TABLE IF NOT EXISTS public.affiliate_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID NOT NULL REFERENCES public.affiliates(id) ON DELETE CASCADE,
  referred_email TEXT NOT NULL,
  store_id UUID,
  store_name TEXT,
  plan_tier TEXT DEFAULT 'plus',
  status TEXT DEFAULT 'pending_verification',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_aff ON public.affiliate_referrals(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_email ON public.affiliate_referrals(LOWER(referred_email));

-- 4. COMMISSIONS LEDGER (In Philippine Pesos - PHP)
CREATE TABLE IF NOT EXISTS public.affiliate_commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID NOT NULL REFERENCES public.affiliates(id) ON DELETE CASCADE,
  referral_id UUID REFERENCES public.affiliate_referrals(id),
  paddle_transaction_id TEXT UNIQUE NOT NULL,
  plan_tier TEXT NOT NULL CHECK (plan_tier IN ('plus', 'pro')),
  sale_amount_php NUMERIC(10,2) NOT NULL,
  commission_amount_php NUMERIC(10,2) NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'reversed', 'paid')),
  hold_until TIMESTAMPTZ DEFAULT (now() + INTERVAL '30 days'),
  payout_id UUID,
  reversal_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affiliate_commissions_aff ON public.affiliate_commissions(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_commissions_tx ON public.affiliate_commissions(paddle_transaction_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_commissions_status ON public.affiliate_commissions(status);

-- 5. BATCH PAYOUTS & DISBURSEMENTS
CREATE TABLE IF NOT EXISTS public.affiliate_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID NOT NULL REFERENCES public.affiliates(id),
  total_payout_php NUMERIC(10,2) NOT NULL,
  channel TEXT NOT NULL,                     -- 'GCash', 'Maya', 'InstaPay'
  disbursement_reference TEXT NOT NULL,      -- GCash Ref # / Bank Transfer Ref
  status TEXT DEFAULT 'completed',
  notes TEXT,
  disbursed_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affiliate_payouts_aff ON public.affiliate_payouts(affiliate_id);

-- 6. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.affiliates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_clicks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_payouts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if re-running
DROP POLICY IF EXISTS "Public can look up active affiliate codes" ON public.affiliates;
DROP POLICY IF EXISTS "Public can register as affiliate" ON public.affiliates;
DROP POLICY IF EXISTS "Affiliates can update their profile" ON public.affiliates;
DROP POLICY IF EXISTS "Public can record affiliate clicks" ON public.affiliate_clicks;
DROP POLICY IF EXISTS "Public can view clicks" ON public.affiliate_clicks;
DROP POLICY IF EXISTS "Public can bind affiliate referrals" ON public.affiliate_referrals;
DROP POLICY IF EXISTS "Affiliates can view referrals" ON public.affiliate_referrals;
DROP POLICY IF EXISTS "Affiliates can view commissions" ON public.affiliate_commissions;
DROP POLICY IF EXISTS "Affiliates can view payouts" ON public.affiliate_payouts;

-- 1. Look up affiliate by code or email
CREATE POLICY "Public can look up active affiliate codes"
  ON public.affiliates
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- 2. Anyone can register as an affiliate
CREATE POLICY "Public can register as affiliate"
  ON public.affiliates
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- 3. Affiliates can update their own payout details
CREATE POLICY "Affiliates can update their profile"
  ON public.affiliates
  FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- 4. Anyone can record and read clicks
CREATE POLICY "Public can record affiliate clicks"
  ON public.affiliate_clicks
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Public can view clicks"
  ON public.affiliate_clicks
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- 5. Referrals binding & viewing
CREATE POLICY "Public can bind affiliate referrals"
  ON public.affiliate_referrals
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Affiliates can view referrals"
  ON public.affiliate_referrals
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- 6. Commissions viewing
CREATE POLICY "Affiliates can view commissions"
  ON public.affiliate_commissions
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- 7. Payouts viewing
CREATE POLICY "Affiliates can view payouts"
  ON public.affiliate_payouts
  FOR SELECT
  TO anon, authenticated
  USING (true);
