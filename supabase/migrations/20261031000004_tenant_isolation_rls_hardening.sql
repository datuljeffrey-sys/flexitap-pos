-- =============================================================================
-- Migration 04: Strict Tenant Isolation & Row-Level Security Hardening
-- Version: 20261031000004
-- Eliminates permissive USING (true) on merchant_feedback and ticket_notes
-- =============================================================================

-- 1. Profiles RLS
DROP POLICY IF EXISTS "Merchants can read and update own profile" ON public.profiles;
CREATE POLICY "Merchants can read and update own profile"
  ON public.profiles
  FOR ALL
  TO authenticated
  USING (id::text = auth.uid()::text)
  WITH CHECK (id::text = auth.uid()::text);

-- 2. Stores RLS
DROP POLICY IF EXISTS "Merchants manage own stores" ON public.stores;
CREATE POLICY "Merchants manage own stores"
  ON public.stores
  FOR ALL
  TO authenticated
  USING (owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text)
  WITH CHECK (owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text);

-- 3. Daily Sales Summaries RLS
DROP POLICY IF EXISTS "Merchants can read own store daily sales summaries" ON public.daily_sales_summaries;
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
      AND lower(role) IN ('dev', 'developer', 'admin', 'staff', 'support')
    )
  );

-- 4. Tickets RLS
DROP POLICY IF EXISTS "Merchants and staff can read tickets" ON public.tickets;
CREATE POLICY "Merchants and staff can read tickets"
  ON public.tickets
  FOR SELECT
  TO authenticated
  USING (
    merchant_id::text = auth.uid()::text
    OR lower(contact_email) = lower(auth.email())
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

-- 5. Ticket Notes RLS: Strict Tenant Isolation (Fixing permissive USING (true))
DROP POLICY IF EXISTS "Allow reading ticket_notes" ON public.ticket_notes;
DROP POLICY IF EXISTS "Tenant scoped ticket notes access" ON public.ticket_notes;
CREATE POLICY "Tenant scoped ticket notes access"
  ON public.ticket_notes
  FOR SELECT
  TO authenticated
  USING (
    ticket_id IN (
      SELECT id FROM public.tickets
      WHERE merchant_id::text = auth.uid()::text
        OR lower(contact_email) = lower(auth.email())
        OR store_name IN (
          SELECT store_name FROM public.profiles WHERE id::text = auth.uid()::text
        )
        OR store_name IN (
          SELECT name FROM public.stores WHERE owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text
        )
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin', 'staff', 'support')
    )
  );

-- 6. Merchant Feedback RLS: Strict Tenant Isolation (Fixing permissive USING (true))
DROP POLICY IF EXISTS "Allow select merchant_feedback" ON public.merchant_feedback;
DROP POLICY IF EXISTS "Tenant scoped feedback read access" ON public.merchant_feedback;
CREATE POLICY "Tenant scoped feedback read access"
  ON public.merchant_feedback
  FOR SELECT
  TO authenticated
  USING (
    lower(merchant_email) = lower(auth.email())
    OR store_id IN (
      SELECT id::text FROM public.stores WHERE owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin', 'staff', 'support')
    )
  );

DROP POLICY IF EXISTS "Allow update merchant_feedback" ON public.merchant_feedback;
DROP POLICY IF EXISTS "Staff only feedback update access" ON public.merchant_feedback;
CREATE POLICY "Staff only feedback update access"
  ON public.merchant_feedback
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id::text = auth.uid()::text 
      AND lower(role) IN ('dev', 'developer', 'admin')
    )
  );
