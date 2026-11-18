-- ==============================================================================
-- FLEXITAP RELEASE BUG BACKLOG & QUALITY STAGING TABLE
-- ==============================================================================
-- Stores AI-diagnosed code defects and engineering blueprints staged for
-- the next app release / version update.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.release_bug_backlog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id TEXT,
    ticket_number TEXT,
    title TEXT NOT NULL,
    category TEXT DEFAULT 'general',
    severity TEXT NOT NULL DEFAULT 'high',
    target_version TEXT NOT NULL DEFAULT 'v2.4.1',
    component TEXT,
    file_path TEXT,
    line_number INT,
    github_link TEXT,
    root_cause TEXT,
    recommended_fix TEXT,
    test_suite TEXT,
    status TEXT NOT NULL DEFAULT 'staged', -- staged, in_progress, fixed_in_test, shipped
    staged_by TEXT,
    fixed_by TEXT,
    shipped_in_version TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_release_bug_backlog_status ON public.release_bug_backlog(status);
CREATE INDEX IF NOT EXISTS idx_release_bug_backlog_target_version ON public.release_bug_backlog(target_version);

ALTER TABLE public.release_bug_backlog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow staff to read and manage release bug backlog" ON public.release_bug_backlog;
CREATE POLICY "Allow staff to read and manage release bug backlog"
    ON public.release_bug_backlog FOR ALL
    TO authenticated, anon
    USING (true)
    WITH CHECK (true);
