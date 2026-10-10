-- ========================================================================
-- FlexiTap Ad-hoc Remote Support Sessions Migration (RustDesk Integration)
-- ========================================================================

-- 1. Create table if missing
create table if not exists public.remote_support_sessions (
  id uuid primary key default gen_random_uuid(),
  code varchar(6) not null unique,
  status varchar(20) not null default 'pending', -- pending, client_ready, active, ended, expired
  staff_user_id uuid references auth.users(id),
  rustdesk_id varchar(20),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Ensure all columns exist even if the table already existed previously
alter table public.remote_support_sessions add column if not exists code varchar(6);
alter table public.remote_support_sessions add column if not exists status varchar(20) default 'pending';
alter table public.remote_support_sessions add column if not exists staff_user_id uuid references auth.users(id);
alter table public.remote_support_sessions add column if not exists rustdesk_id varchar(20);
alter table public.remote_support_sessions add column if not exists created_at timestamp with time zone default timezone('utc'::text, now());
alter table public.remote_support_sessions add column if not exists updated_at timestamp with time zone default timezone('utc'::text, now());

-- Drop NOT NULL on created_by / staff_user_id if present from an older schema
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'remote_support_sessions' and column_name = 'created_by') then
    alter table public.remote_support_sessions alter column created_by drop not null;
    alter table public.remote_support_sessions alter column created_by set default auth.uid();
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'remote_support_sessions' and column_name = 'staff_user_id') then
    alter table public.remote_support_sessions alter column staff_user_id drop not null;
    alter table public.remote_support_sessions alter column staff_user_id set default auth.uid();
  end if;
end $$;

-- Migrate legacy column names if present
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'remote_support_sessions' and column_name = 'agent_id') then
    execute 'update public.remote_support_sessions set staff_user_id = agent_id where staff_user_id is null';
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'remote_support_sessions' and column_name = 'session_code') then
    execute 'update public.remote_support_sessions set code = session_code where code is null';
  end if;
end $$;

-- Index for fast lookup by 6-character session code
create index if not exists idx_remote_support_sessions_code on public.remote_support_sessions(code);

-- 2. ENABLE ROW LEVEL SECURITY (RLS)
alter table public.remote_support_sessions enable row level security;

-- Drop existing policies if re-running
drop policy if exists "Staff can view their own remote support sessions" on public.remote_support_sessions;
drop policy if exists "Staff can update their own remote support sessions" on public.remote_support_sessions;

-- RLS Policy: Authenticated staff can view their sessions (Required for Supabase Realtime UPDATE events)
create policy "Staff can view their own remote support sessions"
on public.remote_support_sessions
for select
to authenticated
using (
  staff_user_id = auth.uid()
  or (
    case when exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'remote_support_sessions' and column_name = 'created_by')
         then created_by = auth.uid()
         else false
    end
  )
  or exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
    and lower(profiles.role) in ('dev', 'developer', 'admin', 'staff', 'support')
  )
);

-- RLS Policy: Authenticated staff can update their sessions
create policy "Staff can update their own remote support sessions"
on public.remote_support_sessions
for update
to authenticated
using (
  staff_user_id = auth.uid()
  or (
    case when exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'remote_support_sessions' and column_name = 'created_by')
         then created_by = auth.uid()
         else false
    end
  )
  or exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
    and lower(profiles.role) in ('dev', 'developer', 'admin', 'staff', 'support')
  )
);

-- 3. Add table to Supabase Realtime publication
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'remote_support_sessions'
  ) then
    alter publication supabase_realtime add table public.remote_support_sessions;
  end if;
end $$;

-- 4. DROP EXISTING FUNCTIONS (Resolves ERROR 42P13 return type conflict)
drop function if exists public.create_support_session() cascade;
drop function if exists public.submit_rustdesk_id(text, text) cascade;
drop function if exists public.get_support_session_status(text) cascade;
drop function if exists public.staff_start_session(uuid) cascade;

-- 5. Stored Procedure: Staff creates new support session with random 6-character code
create or replace function public.create_support_session()
returns table (id uuid, code text) language plpgsql security definer as $func$
declare
  new_code text;
  new_id uuid;
  current_user_id uuid;
begin
  new_code := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 6));
  current_user_id := auth.uid();
  
  if exists (
    select 1 from information_schema.columns 
    where table_schema = 'public' and table_name = 'remote_support_sessions' and column_name = 'created_by'
  ) then
    execute 'insert into public.remote_support_sessions (code, staff_user_id, created_by, status) values ($1, $2, $2, $3) returning id'
    into new_id
    using new_code, current_user_id, 'pending';
  else
    insert into public.remote_support_sessions (code, staff_user_id, status)
    values (new_code, current_user_id, 'pending')
    returning remote_support_sessions.id into new_id;
  end if;

  return query select new_id, new_code;
end;
$func$;

-- 6. Stored Procedure: Merchant submits their RustDesk ID
create or replace function public.submit_rustdesk_id(p_code text, p_rustdesk_id text)
returns boolean language plpgsql security definer as $func$
begin
  update public.remote_support_sessions
  set rustdesk_id = trim(p_rustdesk_id),
      status = 'client_ready',
      updated_at = now()
  where code = upper(trim(p_code)) and status in ('pending', 'client_ready');
  return found;
end;
$func$;

-- 7. Stored Procedure: Safe status check for merchant polling (no broad table access)
create or replace function public.get_support_session_status(p_code text)
returns table (id uuid, status varchar, rustdesk_id varchar) language plpgsql security definer as $func$
begin
  return query
  select s.id, s.status, s.rustdesk_id
  from public.remote_support_sessions s
  where s.code = upper(trim(p_code))
  order by s.created_at desc limit 1;
end;
$func$;

-- 8. Stored Procedure: Staff starts/activates session
create or replace function public.staff_start_session(p_session_id uuid)
returns boolean language plpgsql security definer as $func$
begin
  update public.remote_support_sessions
  set status = 'active', updated_at = now()
  where id = p_session_id;
  return found;
end;
$func$;

-- 9. Grant Permissions to authenticated and anon users
grant execute on function public.create_support_session to authenticated;
grant execute on function public.staff_start_session to authenticated;
grant execute on function public.submit_rustdesk_id to anon, authenticated;
grant execute on function public.get_support_session_status to anon, authenticated;
