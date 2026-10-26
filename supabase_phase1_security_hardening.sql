-- =============================================================================
-- FlexiTap Enterprise Security Hardening: Phase 1 Cloud & RLS Shield
-- Zero-Downtime Migration for Daily Sales, Affiliates, Tickets & Remote Sessions
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. HARDEN DAILY SALES SUMMARIES (Financial Data Shield)
-- -----------------------------------------------------------------------------
ALTER TABLE public.daily_sales_summaries ENABLE ROW LEVEL SECURITY;

-- Drop insecure open policies
DROP POLICY IF EXISTS "Store owners can read their sales summaries" ON public.daily_sales_summaries;
DROP POLICY IF EXISTS "Master terminals can upsert sales summaries" ON public.daily_sales_summaries;
DROP POLICY IF EXISTS "Enable all operations for authenticated users" ON public.daily_sales_summaries;
DROP POLICY IF EXISTS "Enable select and upsert for anon users" ON public.daily_sales_summaries;
DROP POLICY IF EXISTS "Merchants can read own store daily sales summaries" ON public.daily_sales_summaries;
DROP POLICY IF EXISTS "Merchants and POS can upsert own store daily sales summaries" ON public.daily_sales_summaries;

-- Policy A: Merchants & Dev Staff can SELECT only their own store records
CREATE POLICY "Merchants can read own store daily sales summaries"
  ON public.daily_sales_summaries
  FOR SELECT
  TO authenticated
  USING (
    store_id::text = auth.uid()::text
    OR store_id::text IN (
      SELECT id::text FROM public.stores 
      WHERE owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text
    )
    OR store_id::text IN (
      SELECT store_id::text FROM public.profiles
      WHERE id::text = auth.uid()::text AND store_id IS NOT NULL
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin')
    )
  );

-- Policy B: POS Master Terminals & Authenticated Merchants can UPSERT their own store records
CREATE POLICY "Merchants and POS can upsert own store daily sales summaries"
  ON public.daily_sales_summaries
  FOR ALL
  TO authenticated
  USING (
    store_id::text = auth.uid()::text
    OR store_id::text IN (
      SELECT id::text FROM public.stores 
      WHERE owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text
    )
    OR store_id::text IN (
      SELECT store_id::text FROM public.profiles
      WHERE id::text = auth.uid()::text AND store_id IS NOT NULL
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin')
    )
  )
  WITH CHECK (
    store_id::text = auth.uid()::text
    OR store_id::text IN (
      SELECT id::text FROM public.stores 
      WHERE owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text
    )
    OR store_id::text IN (
      SELECT store_id::text FROM public.profiles
      WHERE id::text = auth.uid()::text AND store_id IS NOT NULL
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin')
    )
  );


-- -----------------------------------------------------------------------------
-- 2. HARDEN AFFILIATES (Bank Account Hijack Prevention)
-- -----------------------------------------------------------------------------
ALTER TABLE public.affiliates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Affiliates can update their profile" ON public.affiliates;
DROP POLICY IF EXISTS "Affiliates can update their own profile" ON public.affiliates;

-- Only authenticated users matching the affiliate record or admin can update payout bank details
CREATE POLICY "Affiliates can update their own profile"
  ON public.affiliates
  FOR UPDATE
  TO authenticated
  USING (
    user_id::text = auth.uid()::text
    OR lower(email) = lower(auth.email())
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin')
    )
  )
  WITH CHECK (
    user_id::text = auth.uid()::text
    OR lower(email) = lower(auth.email())
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin')
    )
  );


-- -----------------------------------------------------------------------------
-- 3. HARDEN SUPPORT TICKETS & TELEMETRY (PII Shield)
-- -----------------------------------------------------------------------------
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow reading tickets" ON public.tickets;
DROP POLICY IF EXISTS "Allow updating tickets" ON public.tickets;
DROP POLICY IF EXISTS "Merchants and staff can read tickets" ON public.tickets;
DROP POLICY IF EXISTS "Staff can update tickets" ON public.tickets;

-- Merchants read only their store tickets; Operations/Dev read all
CREATE POLICY "Merchants and staff can read tickets"
  ON public.tickets
  FOR SELECT
  TO authenticated
  USING (
    lower(contact_email) = lower(auth.email())
    OR store_name IN (
      SELECT store_name FROM public.profiles WHERE id::text = auth.uid()::text
    )
    OR store_name IN (
      SELECT name FROM public.stores WHERE owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin', 'staff', 'support')
    )
  );

-- Only verified Staff / Dev can update ticket resolution, status, and assignment
CREATE POLICY "Staff can update tickets"
  ON public.tickets
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin', 'staff', 'support')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin', 'staff', 'support')
    )
  );


-- -----------------------------------------------------------------------------
-- 4. HARDEN REMOTE SUPPORT SESSIONS (Prevent Machine ID Enumeration)
-- -----------------------------------------------------------------------------
ALTER TABLE public.remote_support_sessions ENABLE ROW LEVEL SECURITY;

-- Drop table-level open dump policy (clients look up via get_support_session_status RPC)
DROP POLICY IF EXISTS "Allow session lookup by code" ON public.remote_support_sessions;
DROP POLICY IF EXISTS "Staff can view remote support sessions" ON public.remote_support_sessions;

CREATE POLICY "Staff can view remote support sessions"
  ON public.remote_support_sessions
  FOR SELECT
  TO authenticated
  USING (
    staff_user_id::text = auth.uid()::text
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin', 'staff', 'support')
    )
  );

-- Reload PostgREST schema cache immediately
NOTIFY pgrst, 'reload schema';
