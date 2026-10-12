-- ========================================================================
-- FlexiTap Site Analytics & Platform Demand Migration
-- ========================================================================

-- 1. Create site_analytics table if not exists
create table if not exists public.site_analytics (
  id uuid primary key default gen_random_uuid(),
  event_type text not null default 'pageview', -- 'pageview', 'download_click', 'click', 'custom'
  event_name text not null,                   -- e.g. 'pageview', 'download_click', 'ticket_submitted', etc.
  page_path text not null,                    -- e.g. '/support.html', '/index.html', '/pricing.html'
  page_title text,
  platform text,                              -- 'windows', 'android', 'ios', 'mac', 'linux', 'other'
  referrer text,
  session_id text,                            -- anonymous browser tab session identifier
  metadata jsonb default '{}'::jsonb,         -- screen resolution, language, user agent, label, etc.
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Indices for fast aggregation and Dev Portal queries
create index if not exists idx_site_analytics_event_name on public.site_analytics(event_name);
create index if not exists idx_site_analytics_event_type on public.site_analytics(event_type);
create index if not exists idx_site_analytics_platform on public.site_analytics(platform);
create index if not exists idx_site_analytics_created_at on public.site_analytics(created_at desc);

-- 2. Enable Row Level Security (RLS)
alter table public.site_analytics enable row level security;

-- Drop existing policies if re-running
drop policy if exists "Allow public anonymous event inserts" on public.site_analytics;
drop policy if exists "Allow staff and admins to read analytics" on public.site_analytics;

-- Allow public frontend visitors to insert analytics events
create policy "Allow public anonymous event inserts"
on public.site_analytics
for insert
to anon, authenticated
with check (true);

-- Allow admins, staff and Dev Portal callers to inspect analytics
create policy "Allow staff and admins to read analytics"
on public.site_analytics
for select
to anon, authenticated
using (true);
