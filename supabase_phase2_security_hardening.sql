-- ============================================================================
-- FLEXITAP POS — PHASE 2 ENTERPRISE SECURITY HARDENING MIGRATION
-- Verified against all exact table & column names in your Supabase migrations.
-- ============================================================================

-- 1. STAFF VERIFICATION HELPER FUNCTION (SECURITY DEFINER)
create or replace function public.is_flexitap_staff()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_email text;
begin
  if auth.uid() is null then
    return false;
  end if;

  select lower(coalesce(p.role, '')), lower(coalesce(p.email, auth.jwt() ->> 'email', ''))
    into v_role, v_email
    from public.profiles p
   where p.id = auth.uid();

  if v_role in ('admin', 'super_admin', 'dev', 'developer', 'devops', 'support', 'staff', 'ops', 'agent') then
    return true;
  end if;

  if v_email like '%@flexitapapp.com' or v_email like '%@flexitap.io' then
    return true;
  end if;

  return false;
end;
$$;

-- 2. PREVENT PRIVILEGE ESCALATION ON public.profiles
-- Uses to_jsonb(new) / to_jsonb(old) so it never fails if an optional column is absent
create or replace function public.guard_profile_sensitive_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_jwt_role text := coalesce(auth.jwt() ->> 'role', current_setting('request.jwt.claim.role', true), '');
  v_caller_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_is_staff boolean := false;
  v_new_role text := lower(coalesce(new.role, 'owner'));
  v_restricted_roles text[] := array['admin', 'super_admin', 'dev', 'developer', 'devops', 'support', 'staff', 'ops', 'agent'];
begin
  if v_jwt_role = 'service_role' or current_user in ('postgres', 'supabase_admin', 'supabase_auth_admin') then
    return new;
  end if;

  if v_caller_email like '%@flexitapapp.com' or v_caller_email like '%@flexitap.io' then
    v_is_staff := true;
  elsif auth.uid() is not null then
    v_is_staff := public.is_flexitap_staff();
  end if;

  if v_is_staff then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if v_new_role = any(v_restricted_roles) then
      new.role := 'owner';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.role is distinct from old.role then
      if v_new_role = any(v_restricted_roles) then
        new.role := old.role;
      end if;
    end if;
    return new;
  end if;

  return new;
end;
$$;

do $$
begin
  if to_regclass('public.profiles') is not null then
    execute 'drop trigger if exists trg_guard_profile_sensitive_columns on public.profiles';
    execute 'create trigger trg_guard_profile_sensitive_columns before insert or update on public.profiles for each row execute function public.guard_profile_sensitive_columns()';

    execute 'alter table public.profiles enable row level security';
    execute 'drop policy if exists "Public profiles are viewable by everyone" on public.profiles';
    execute 'drop policy if exists "Anyone can view profiles" on public.profiles';
    execute 'drop policy if exists "Users can view own profile or staff can view all" on public.profiles';
    execute 'drop policy if exists "Users can update own profile or staff can update all" on public.profiles';
    execute 'drop policy if exists "Users can insert own profile or staff can insert" on public.profiles';

    execute $p$
      create policy "Users can view own profile or staff can view all"
        on public.profiles for select
        to authenticated
        using (auth.uid() = id or public.is_flexitap_staff())
    $p$;

    execute $p$
      create policy "Users can insert own profile or staff can insert"
        on public.profiles for insert
        to authenticated
        with check (auth.uid() = id or public.is_flexitap_staff())
    $p$;

    execute $p$
      create policy "Users can update own profile or staff can update all"
        on public.profiles for update
        to authenticated
        using (auth.uid() = id or public.is_flexitap_staff())
        with check (auth.uid() = id or public.is_flexitap_staff())
    $p$;
  end if;
end;
$$;

-- 3. LOCK DOWN CRM TABLES (IF PRESENT — matches supabase_crm_migration.sql)
do $$
begin
  if to_regclass('public.merchant_crm_accounts') is not null then
    execute 'alter table public.merchant_crm_accounts enable row level security';
    execute 'drop policy if exists "Enable all access for CRM accounts" on public.merchant_crm_accounts';
    execute 'drop policy if exists "Allow staff full access to crm accounts" on public.merchant_crm_accounts';
    execute 'drop policy if exists "CRM accounts access for owner and staff" on public.merchant_crm_accounts';
    execute $p$
      create policy "CRM accounts access for owner and staff"
        on public.merchant_crm_accounts for all
        to authenticated
        using (public.is_flexitap_staff() or profile_id = auth.uid())
        with check (public.is_flexitap_staff() or profile_id = auth.uid())
    $p$;
  end if;

  if to_regclass('public.merchant_crm_contacts') is not null then
    execute 'alter table public.merchant_crm_contacts enable row level security';
    execute 'drop policy if exists "Enable all access for CRM contacts" on public.merchant_crm_contacts';
    execute 'drop policy if exists "Allow staff full access to crm contacts" on public.merchant_crm_contacts';
    execute 'drop policy if exists "CRM contacts access for owner and staff" on public.merchant_crm_contacts';
    execute $p$
      create policy "CRM contacts access for owner and staff"
        on public.merchant_crm_contacts for all
        to authenticated
        using (public.is_flexitap_staff())
        with check (public.is_flexitap_staff())
    $p$;
  end if;

  if to_regclass('public.merchant_crm_assets') is not null then
    execute 'alter table public.merchant_crm_assets enable row level security';
    execute 'drop policy if exists "Enable all access for CRM assets" on public.merchant_crm_assets';
    execute 'drop policy if exists "Allow staff full access to crm assets" on public.merchant_crm_assets';
    execute 'drop policy if exists "CRM assets access for owner and staff" on public.merchant_crm_assets';
    execute $p$
      create policy "CRM assets access for owner and staff"
        on public.merchant_crm_assets for all
        to authenticated
        using (public.is_flexitap_staff())
        with check (public.is_flexitap_staff())
    $p$;
  end if;

  if to_regclass('public.merchant_crm_subscriptions') is not null then
    execute 'alter table public.merchant_crm_subscriptions enable row level security';
    execute 'drop policy if exists "Enable all access for CRM subscriptions" on public.merchant_crm_subscriptions';
    execute 'drop policy if exists "Allow staff full access to crm subscriptions" on public.merchant_crm_subscriptions';
    execute 'drop policy if exists "CRM subscriptions access for owner and staff" on public.merchant_crm_subscriptions';
    execute $p$
      create policy "CRM subscriptions access for owner and staff"
        on public.merchant_crm_subscriptions for all
        to authenticated
        using (public.is_flexitap_staff())
        with check (public.is_flexitap_staff())
    $p$;
  end if;
end;
$$;

-- 4. LOCK DOWN merchant_feedback & ticket_notifications
-- Matches exact columns in supabase_merchant_feedback_migration.sql (merchant_email, store_id)
-- and supabase_ticket_emails_migration.sql (recipient_email)
do $$
begin
  if to_regclass('public.merchant_feedback') is not null then
    execute 'alter table public.merchant_feedback enable row level security';
    execute 'drop policy if exists "Allow select merchant_feedback" on public.merchant_feedback';
    execute 'drop policy if exists "Allow update merchant_feedback" on public.merchant_feedback';
    execute 'drop policy if exists "Allow anon and authenticated to read merchant_feedback" on public.merchant_feedback';
    execute 'drop policy if exists "Allow staff to update merchant_feedback" on public.merchant_feedback';
    execute 'drop policy if exists "Authenticated users and staff read merchant_feedback" on public.merchant_feedback';
    execute 'drop policy if exists "Staff can update merchant_feedback" on public.merchant_feedback';

    execute $p$
      create policy "Authenticated users and staff read merchant_feedback"
        on public.merchant_feedback for select
        to authenticated
        using (
          public.is_flexitap_staff()
          or store_id = auth.uid()::text
          or lower(coalesce(merchant_email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
        )
    $p$;

    execute $p$
      create policy "Staff can update merchant_feedback"
        on public.merchant_feedback for update
        to authenticated
        using (public.is_flexitap_staff())
        with check (public.is_flexitap_staff())
    $p$;
  end if;

  if to_regclass('public.ticket_notifications') is not null then
    execute 'alter table public.ticket_notifications enable row level security';
    execute 'drop policy if exists "Allow select ticket_notifications" on public.ticket_notifications';
    execute 'drop policy if exists "Allow insert ticket_notifications" on public.ticket_notifications';
    execute 'drop policy if exists "Allow all select ticket_notifications" on public.ticket_notifications';
    execute 'drop policy if exists "Allow all insert ticket_notifications" on public.ticket_notifications';
    execute 'drop policy if exists "Authenticated select ticket_notifications" on public.ticket_notifications';
    execute 'drop policy if exists "Authenticated insert ticket_notifications" on public.ticket_notifications';

    execute $p$
      create policy "Authenticated select ticket_notifications"
        on public.ticket_notifications for select
        to authenticated
        using (
          public.is_flexitap_staff()
          or lower(coalesce(recipient_email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
        )
    $p$;

    execute $p$
      create policy "Authenticated insert ticket_notifications"
        on public.ticket_notifications for insert
        to authenticated
        with check (true)
    $p$;
  end if;
end;
$$;

-- 5. LOCK DOWN AFFILIATE REFERRALS, COMMISSIONS & PAYOUTS
-- Matches exact policy names in supabase_affiliate_ph.sql
do $$
begin
  if to_regclass('public.affiliate_referrals') is not null and to_regclass('public.affiliates') is not null then
    execute 'alter table public.affiliate_referrals enable row level security';
    execute 'drop policy if exists "Affiliates can view referrals" on public.affiliate_referrals';
    execute 'drop policy if exists "Public select referrals" on public.affiliate_referrals';
    execute 'drop policy if exists "Public update referrals" on public.affiliate_referrals';
    execute 'drop policy if exists "Affiliates and staff select referrals" on public.affiliate_referrals';
    execute 'drop policy if exists "Staff update referrals" on public.affiliate_referrals';

    execute $p$
      create policy "Affiliates and staff select referrals"
        on public.affiliate_referrals for select
        to authenticated
        using (
          public.is_flexitap_staff()
          or exists (
            select 1 from public.affiliates a
            where a.id = affiliate_referrals.affiliate_id
              and (a.user_id = auth.uid() or lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', '')))
          )
        )
    $p$;

    execute $p$
      create policy "Staff update referrals"
        on public.affiliate_referrals for update
        to authenticated
        using (public.is_flexitap_staff())
        with check (public.is_flexitap_staff())
    $p$;
  end if;

  if to_regclass('public.affiliate_commissions') is not null and to_regclass('public.affiliates') is not null then
    execute 'alter table public.affiliate_commissions enable row level security';
    execute 'drop policy if exists "Affiliates can view commissions" on public.affiliate_commissions';
    execute 'drop policy if exists "Public select commissions" on public.affiliate_commissions';
    execute 'drop policy if exists "Public manage commissions" on public.affiliate_commissions';
    execute 'drop policy if exists "Affiliates and staff select commissions" on public.affiliate_commissions';
    execute 'drop policy if exists "Staff manage commissions" on public.affiliate_commissions';

    execute $p$
      create policy "Affiliates and staff select commissions"
        on public.affiliate_commissions for select
        to authenticated
        using (
          public.is_flexitap_staff()
          or exists (
            select 1 from public.affiliates a
            where a.id = affiliate_commissions.affiliate_id
              and (a.user_id = auth.uid() or lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', '')))
          )
        )
    $p$;

    execute $p$
      create policy "Staff manage commissions"
        on public.affiliate_commissions for all
        to authenticated
        using (public.is_flexitap_staff())
        with check (public.is_flexitap_staff())
    $p$;
  end if;

  if to_regclass('public.affiliate_payouts') is not null and to_regclass('public.affiliates') is not null then
    execute 'alter table public.affiliate_payouts enable row level security';
    execute 'drop policy if exists "Affiliates can view payouts" on public.affiliate_payouts';
    execute 'drop policy if exists "Public select payouts" on public.affiliate_payouts';
    execute 'drop policy if exists "Public update payouts" on public.affiliate_payouts';
    execute 'drop policy if exists "Affiliates and staff select payouts" on public.affiliate_payouts';
    execute 'drop policy if exists "Staff update payouts" on public.affiliate_payouts';

    execute $p$
      create policy "Affiliates and staff select payouts"
        on public.affiliate_payouts for select
        to authenticated
        using (
          public.is_flexitap_staff()
          or exists (
            select 1 from public.affiliates a
            where a.id = affiliate_payouts.affiliate_id
              and (a.user_id = auth.uid() or lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', '')))
          )
        )
    $p$;

    execute $p$
      create policy "Staff update payouts"
        on public.affiliate_payouts for update
        to authenticated
        using (public.is_flexitap_staff())
        with check (public.is_flexitap_staff())
    $p$;
  end if;
end;
$$;

-- 6. HARDEN SUPPORT SESSION RPCs (REQUIRE STAFF AUTHENTICATION)
create or replace function public.create_support_session()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_id uuid;
  v_attempts int := 0;
begin
  if not public.is_flexitap_staff() then
    raise exception 'Access Denied: Only authorized FlexiTap staff can generate support sessions.';
  end if;

  loop
    v_attempts := v_attempts + 1;
    v_code := lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');

    exit when not exists (
      select 1 from public.support_sessions
      where session_code = v_code
        and status in ('waiting', 'active')
        and expires_at > now()
    );

    if v_attempts > 25 then
      raise exception 'Unable to allocate unique 6-digit support session code';
    end if;
  end loop;

  insert into public.support_sessions (session_code, staff_id, status, expires_at)
  values (v_code, auth.uid(), 'waiting', now() + interval '15 minutes')
  returning id into v_id;

  return jsonb_build_object(
    'session_id', v_id,
    'code', v_code
  );
end;
$$;

create or replace function public.staff_start_session(p_session_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_flexitap_staff() then
    raise exception 'Access Denied: Only authorized FlexiTap staff can start support sessions.';
  end if;

  update public.support_sessions
     set status = 'active'
   where id = p_session_id;
  return found;
end;
$$;
