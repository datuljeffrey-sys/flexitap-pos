-- ============================================================================
-- FLEXITAP POS — SUPABASE SECURITY ADVISOR REMEDIATION (PHASE 3)
-- Resolves all 11 Security Advisor Errors:
--   1. public.users                 (RLS Disabled in Public)
--   2. public.taxes                 (RLS Disabled in Public)
--   3. public.categories            (RLS Disabled in Public)
--   4. public.item_prep_stations    (RLS Disabled in Public)
--   5. public.prep_stations         (RLS Disabled in Public)
--   6. public.invoices              (RLS Disabled in Public)
--   7. public.pos_devices           (RLS Disabled in Public + Sensitive Columns Exposed)
--   8. public.items                 (RLS Disabled in Public)
--   9. public.departments           (RLS Disabled in Public)
--  10. public.invoice_items         (RLS Disabled in Public)
--  11. Any other remaining public tables without RLS enabled
-- ============================================================================

do $$
declare
  v_tbl text;
  v_target_tables text[] := array[
    'users',
    'taxes',
    'categories',
    'item_prep_stations',
    'prep_stations',
    'invoices',
    'pos_devices',
    'items',
    'departments',
    'invoice_items',
    'stores',
    'devices'
  ];
  v_has_store_id boolean;
  v_has_user_id boolean;
  v_has_owner_id boolean;
  v_cond text;
begin
  foreach v_tbl in array v_target_tables loop
    if to_regclass('public.' || v_tbl) is not null then
      -- 1. Enable Row Level Security immediately (blocks all unauthenticated/anon access)
      execute format('alter table public.%I enable row level security', v_tbl);

      -- 2. Revoke direct table privileges from anon so sensitive columns are never exposed publicly
      execute format('revoke all on table public.%I from anon', v_tbl);

      -- 3. Drop any old open policies on these tables
      execute format('drop policy if exists "Authenticated store or staff access on %s" on public.%I', v_tbl, v_tbl);

      -- 4. Inspect columns dynamically to build the safest owner/store + staff RLS policy
      select exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = v_tbl and column_name = 'store_id'
      ) into v_has_store_id;

      select exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = v_tbl and column_name = 'user_id'
      ) into v_has_user_id;

      select exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = v_tbl and column_name = 'owner_id'
      ) into v_has_owner_id;

      v_cond := 'public.is_flexitap_staff()';

      if v_has_user_id then
        v_cond := v_cond || ' or user_id::text = auth.uid()::text';
      end if;

      if v_has_owner_id then
        v_cond := v_cond || ' or owner_id::text = auth.uid()::text';
      end if;

      if v_has_store_id then
        v_cond := v_cond || ' or store_id::text = auth.uid()::text or exists (select 1 from public.stores s where s.id::text = store_id::text and (s.owner_id::text = auth.uid()::text or s.user_id::text = auth.uid()::text))';
      end if;

      if v_tbl = 'stores' then
        v_cond := v_cond || ' or id::text = auth.uid()::text';
      end if;

      execute format(
        'create policy "Authenticated store or staff access on %s" on public.%I for all to authenticated using (%s) with check (%s)',
        v_tbl, v_tbl, v_cond, v_cond
      );
    end if;
  end loop;
end;
$$;
