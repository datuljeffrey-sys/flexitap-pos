-- =============================================================================
-- FlexiTap Enterprise Security Hardening: Phase 2 Complete Cloud & RBAC Shield
-- Zero-Downtime Migration for Privilege Escalation, CRM, Feedback, Affiliates & RPCs
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. HELPER FUNCTION: VERIFY IF CALLER IS AUTHORIZED BACKEND STAFF
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_flexitap_staff()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_email text := lower(COALESCE(auth.email(), ''));
  v_role text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN false;
  END IF;

  -- Check profile role
  SELECT lower(COALESCE(role, '')) INTO v_role
  FROM public.profiles
  WHERE id::text = v_uid::text
  LIMIT 1;

  IF v_role IN ('dev', 'developer', 'admin', 'super_admin', 'staff', 'support', 'ops', 'devops', 'agent') THEN
    RETURN true;
  END IF;

  -- Official corporate domain fallback (provided not registered as affiliate)
  IF (v_email LIKE '%@flexitapapp.com' OR v_email LIKE '%@flexitap.io') THEN
    IF NOT EXISTS (SELECT 1 FROM public.affiliates WHERE lower(email) = v_email) THEN
      RETURN true;
    END IF;
  END IF;

  RETURN false;
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_flexitap_staff() TO authenticated, anon;


-- -----------------------------------------------------------------------------
-- 2. PREVENT PRIVILEGE ESCALATION ON public.profiles (Trigger + RLS)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_profile_sensitive_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_jwt_role text := COALESCE(current_setting('request.jwt.claim.role', true), '');
  v_email text := lower(COALESCE(NEW.email, auth.email(), ''));
  v_is_staff_caller boolean := false;
BEGIN
  -- Allow service_role or internal postgres superuser (e.g. Paddle webhooks / SQL editor)
  IF v_jwt_role = 'service_role' OR current_user IN ('postgres', 'supabase_admin') AND auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  v_is_staff_caller := public.is_flexitap_staff();

  IF TG_OP = 'INSERT' THEN
    -- Prevent self-assigning staff roles on signup unless corporate domain or admin caller
    IF lower(COALESCE(NEW.role, '')) IN ('dev', 'developer', 'admin', 'super_admin', 'staff', 'support', 'ops', 'devops', 'agent') THEN
      IF NOT v_is_staff_caller AND NOT (v_email LIKE '%@flexitapapp.com' OR v_email LIKE '%@flexitap.io') THEN
        NEW.role := 'owner';
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- If caller is not staff/admin, lock sensitive administrative columns
    IF NOT v_is_staff_caller THEN
      IF NEW.role IS DISTINCT FROM OLD.role THEN
        IF lower(COALESCE(NEW.role, '')) IN ('dev', 'developer', 'admin', 'super_admin', 'staff', 'support', 'ops', 'devops', 'agent') THEN
          NEW.role := OLD.role;
        END IF;
      END IF;

      -- Prevent self-unsuspending or overriding device limits
      NEW.is_account_suspended := OLD.is_account_suspended;
      NEW.max_devices_override := OLD.max_devices_override;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_profile_sensitive_columns ON public.profiles;
CREATE TRIGGER trg_guard_profile_sensitive_columns
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_profile_sensitive_columns();

-- Harden public.profiles RLS (Users see own profile; Staff see all for CRM)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile or staff can read all" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile or staff can update all" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;

CREATE POLICY "Users can read own profile or staff can read all"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    id::text = auth.uid()::text
    OR public.is_flexitap_staff()
  );

CREATE POLICY "Users can insert own profile"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    id::text = auth.uid()::text
    OR public.is_flexitap_staff()
  );

CREATE POLICY "Users can update own profile or staff can update all"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (
    id::text = auth.uid()::text
    OR public.is_flexitap_staff()
  )
  WITH CHECK (
    id::text = auth.uid()::text
    OR public.is_flexitap_staff()
  );


-- -----------------------------------------------------------------------------
-- 3. HARDEN MERCHANT CRM TABLES (Remove Anon Access)
-- -----------------------------------------------------------------------------
ALTER TABLE public.merchant_crm_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_crm_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_crm_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_crm_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow staff full access to crm accounts" ON public.merchant_crm_accounts;
DROP POLICY IF EXISTS "Staff and owner access to crm accounts" ON public.merchant_crm_accounts;
CREATE POLICY "Staff and owner access to crm accounts"
  ON public.merchant_crm_accounts
  FOR ALL
  TO authenticated
  USING (
    profile_id::text = auth.uid()::text
    OR public.is_flexitap_staff()
  )
  WITH CHECK (
    profile_id::text = auth.uid()::text
    OR public.is_flexitap_staff()
  );

DROP POLICY IF EXISTS "Allow staff full access to crm contacts" ON public.merchant_crm_contacts;
DROP POLICY IF EXISTS "Staff access to crm contacts" ON public.merchant_crm_contacts;
CREATE POLICY "Staff access to crm contacts"
  ON public.merchant_crm_contacts
  FOR ALL
  TO authenticated
  USING (public.is_flexitap_staff())
  WITH CHECK (public.is_flexitap_staff());

DROP POLICY IF EXISTS "Allow staff full access to crm assets" ON public.merchant_crm_assets;
DROP POLICY IF EXISTS "Staff access to crm assets" ON public.merchant_crm_assets;
CREATE POLICY "Staff access to crm assets"
  ON public.merchant_crm_assets
  FOR ALL
  TO authenticated
  USING (public.is_flexitap_staff())
  WITH CHECK (public.is_flexitap_staff());

DROP POLICY IF EXISTS "Allow staff full access to crm subscriptions" ON public.merchant_crm_subscriptions;
DROP POLICY IF EXISTS "Staff access to crm subscriptions" ON public.merchant_crm_subscriptions;
CREATE POLICY "Staff access to crm subscriptions"
  ON public.merchant_crm_subscriptions
  FOR ALL
  TO authenticated
  USING (public.is_flexitap_staff())
  WITH CHECK (public.is_flexitap_staff());


-- -----------------------------------------------------------------------------
-- 4. HARDEN MERCHANT FEEDBACK & TICKET NOTIFICATIONS
-- -----------------------------------------------------------------------------
ALTER TABLE public.merchant_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select merchant_feedback" ON public.merchant_feedback;
DROP POLICY IF EXISTS "Allow update merchant_feedback" ON public.merchant_feedback;
DROP POLICY IF EXISTS "Merchants and staff can read feedback" ON public.merchant_feedback;
DROP POLICY IF EXISTS "Staff can update feedback" ON public.merchant_feedback;

CREATE POLICY "Merchants and staff can read feedback"
  ON public.merchant_feedback
  FOR SELECT
  TO authenticated
  USING (
    store_id::text = auth.uid()::text
    OR lower(COALESCE(merchant_email, '')) = lower(COALESCE(auth.email(), ''))
    OR public.is_flexitap_staff()
  );

CREATE POLICY "Staff can update feedback"
  ON public.merchant_feedback
  FOR UPDATE
  TO authenticated
  USING (public.is_flexitap_staff())
  WITH CHECK (public.is_flexitap_staff());

ALTER TABLE public.ticket_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select ticket_notifications" ON public.ticket_notifications;
DROP POLICY IF EXISTS "Recipients and staff can read ticket_notifications" ON public.ticket_notifications;

CREATE POLICY "Recipients and staff can read ticket_notifications"
  ON public.ticket_notifications
  FOR SELECT
  TO authenticated
  USING (
    lower(COALESCE(recipient_email, '')) = lower(COALESCE(auth.email(), ''))
    OR public.is_flexitap_staff()
  );


-- -----------------------------------------------------------------------------
-- 5. HARDEN AFFILIATE REFERRALS, COMMISSIONS & PAYOUTS
-- -----------------------------------------------------------------------------
ALTER TABLE public.affiliate_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Affiliates can view referrals" ON public.affiliate_referrals;
DROP POLICY IF EXISTS "Affiliates and staff can view referrals" ON public.affiliate_referrals;
CREATE POLICY "Affiliates and staff can view referrals"
  ON public.affiliate_referrals
  FOR SELECT
  TO authenticated
  USING (
    affiliate_id IN (
      SELECT id FROM public.affiliates
      WHERE user_id::text = auth.uid()::text OR lower(email) = lower(auth.email())
    )
    OR public.is_flexitap_staff()
  );

DROP POLICY IF EXISTS "Affiliates can view commissions" ON public.affiliate_commissions;
DROP POLICY IF EXISTS "Affiliates and staff can view commissions" ON public.affiliate_commissions;
CREATE POLICY "Affiliates and staff can view commissions"
  ON public.affiliate_commissions
  FOR SELECT
  TO authenticated
  USING (
    affiliate_id IN (
      SELECT id FROM public.affiliates
      WHERE user_id::text = auth.uid()::text OR lower(email) = lower(auth.email())
    )
    OR public.is_flexitap_staff()
  );

DROP POLICY IF EXISTS "Affiliates can view payouts" ON public.affiliate_payouts;
DROP POLICY IF EXISTS "Affiliates and staff can view payouts" ON public.affiliate_payouts;
CREATE POLICY "Affiliates and staff can view payouts"
  ON public.affiliate_payouts
  FOR SELECT
  TO authenticated
  USING (
    affiliate_id IN (
      SELECT id FROM public.affiliates
      WHERE user_id::text = auth.uid()::text OR lower(email) = lower(auth.email())
    )
    OR public.is_flexitap_staff()
  );


-- -----------------------------------------------------------------------------
-- 6. HARDEN REMOTE SUPPORT SECURITY DEFINER RPCs
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_support_session()
RETURNS TABLE (id text, code text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  new_code text;
  new_id uuid;
  current_user_id uuid := auth.uid();
BEGIN
  IF current_user_id IS NULL OR NOT public.is_flexitap_staff() THEN
    RAISE EXCEPTION 'Forbidden: Authorized support or engineering staff role required.';
  END IF;

  new_code := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 6));

  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'remote_support_sessions' AND column_name = 'created_by'
  ) THEN
    EXECUTE 'INSERT INTO public.remote_support_sessions (code, staff_user_id, created_by, status) VALUES ($1, $2, $2, $3) RETURNING id'
    INTO new_id
    USING new_code, current_user_id, 'pending';
  ELSE
    INSERT INTO public.remote_support_sessions (code, staff_user_id, status)
    VALUES (new_code, current_user_id, 'pending')
    RETURNING remote_support_sessions.id INTO new_id;
  END IF;

  RETURN QUERY SELECT new_id::text, new_code::text;
END;
$func$;

CREATE OR REPLACE FUNCTION public.staff_start_session(p_session_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_flexitap_staff() THEN
    RAISE EXCEPTION 'Forbidden: Authorized support or engineering staff role required.';
  END IF;

  UPDATE public.remote_support_sessions
  SET status = 'active', updated_at = now()
  WHERE id = p_session_id;
  RETURN FOUND;
END;
$func$;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
