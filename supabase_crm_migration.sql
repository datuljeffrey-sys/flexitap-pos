-- ========================================================================
-- FlexiTap Merchant CRM Schema Migration
-- Support 5 Core Pillars:
-- 1. Account Information
-- 2. Contact Details
-- 3. Hardware Assets (with Purchase Date, Deployment Date, Expiry Date)
-- 4. Subscription & Paddle Billing
-- 5. Support Tickets
-- ========================================================================

-- 1. MERCHANT CRM ACCOUNTS TABLE
create table if not exists public.merchant_crm_accounts (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete set null,
  legal_name text,
  store_name text not null,
  store_code text unique,
  venue_type text default 'Restaurant / Bar',
  street_address text,
  city text,
  state text,
  postal_code text,
  operating_hours text default 'Mon-Sun: 11:00 AM - 11:00 PM',
  status text default 'active', -- 'active', 'onboarding', 'suspended', 'decommissioned'
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Indices for fast lookups
create index if not exists idx_crm_accounts_profile_id on public.merchant_crm_accounts(profile_id);
create index if not exists idx_crm_accounts_store_code on public.merchant_crm_accounts(store_code);
create index if not exists idx_crm_accounts_status on public.merchant_crm_accounts(status);

-- 2. MERCHANT CONTACTS TABLE
create table if not exists public.merchant_crm_contacts (
  id uuid primary key default gen_random_uuid(),
  account_id uuid references public.merchant_crm_accounts(id) on delete cascade not null,
  name text not null,
  title text default 'Store Manager', -- 'Primary Owner', 'General Manager', 'IT Lead'
  email text,
  phone text,
  is_primary boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create index if not exists idx_crm_contacts_account_id on public.merchant_crm_contacts(account_id);

-- 3. MERCHANT ASSETS (HARDWARE FLEET) TABLE
create table if not exists public.merchant_crm_assets (
  id uuid primary key default gen_random_uuid(),
  account_id uuid references public.merchant_crm_accounts(id) on delete cascade not null,
  asset_name text not null,
  device_model text,          -- e.g. 'Sunmi D2 15.6"', 'Sunmi V2s Handheld', 'Star TSP143 LAN'
  serial_number text,
  location_station text,      -- e.g. 'Front Counter', 'Patio Station #1', 'Kitchen Line'
  purchase_date date,         -- Date hardware was purchased
  deployment_date date,       -- Date deployed to merchant store floor
  expiry_date date,           -- Warranty cutoff or lease expiry date
  status text default 'online', -- 'online', 'offline', 'in_repair', 'retired'
  notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create index if not exists idx_crm_assets_account_id on public.merchant_crm_assets(account_id);
create index if not exists idx_crm_assets_expiry_date on public.merchant_crm_assets(expiry_date);

-- 4. MERCHANT SUBSCRIPTIONS TABLE
create table if not exists public.merchant_crm_subscriptions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid references public.merchant_crm_accounts(id) on delete cascade not null,
  plan_name text default 'Pro POS Tier',
  price_monthly numeric(10,2) default 99.00,
  billing_status text default 'active', -- 'active', 'past_due', 'canceled', 'trial'
  next_billing_date date,
  payment_method text default 'Credit Card',
  paddle_subscription_id text,
  paddle_customer_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create index if not exists idx_crm_subscriptions_account_id on public.merchant_crm_subscriptions(account_id);

-- 5. ENABLE ROW LEVEL SECURITY
alter table public.merchant_crm_accounts enable row level security;
alter table public.merchant_crm_contacts enable row level security;
alter table public.merchant_crm_assets enable row level security;
alter table public.merchant_crm_subscriptions enable row level security;

-- Policies: Dev Portal staff access
drop policy if exists "Allow staff full access to crm accounts" on public.merchant_crm_accounts;
create policy "Allow staff full access to crm accounts"
on public.merchant_crm_accounts for all to anon, authenticated using (true) with check (true);

drop policy if exists "Allow staff full access to crm contacts" on public.merchant_crm_contacts;
create policy "Allow staff full access to crm contacts"
on public.merchant_crm_contacts for all to anon, authenticated using (true) with check (true);

drop policy if exists "Allow staff full access to crm assets" on public.merchant_crm_assets;
create policy "Allow staff full access to crm assets"
on public.merchant_crm_assets for all to anon, authenticated using (true) with check (true);

drop policy if exists "Allow staff full access to crm subscriptions" on public.merchant_crm_subscriptions;
create policy "Allow staff full access to crm subscriptions"
on public.merchant_crm_subscriptions for all to anon, authenticated using (true) with check (true);
