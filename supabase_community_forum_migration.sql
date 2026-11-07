-- ==============================================================================
-- FLEXITAP NATIVE COMMUNITY FORUM SCHEMA & ROW-LEVEL SECURITY (RLS)
-- Dedicated forum tables matching Discourse / Flarum / Loyverse Town spec
-- ==============================================================================

-- 1. COMMUNITY CATEGORIES
CREATE TABLE IF NOT EXISTS public.community_categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  description TEXT,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Seed Default Categories
INSERT INTO public.community_categories (id, name, icon, description, sort_order) VALUES
  ('sales', 'Sales & Cashier', '🛒', 'Checkout speed, open tickets, split tenders, tip pooling, and cash drawers.', 1),
  ('items', 'Items & Catalog', '🏷️', 'Variant matrices, modifiers, barcode scales, and tax configurations.', 2),
  ('printers', 'Printers & Peripherals', '🖨️', 'ESC/POS, Star Micronics, Epson auto-cutters, Bluetooth/LAN, and KDS bump screens.', 3),
  ('inventory', 'Inventory & Reports', '📊', 'Multi-location stock audits, purchase orders, COGS, and daily Z-reports.', 4),
  ('roadmap', 'Feature Requests & Roadmap', '💡', 'Propose new features and vote on upcoming releases.', 5),
  ('plus-pro', 'Plus & Pro Exchange', '👑', 'Multi-terminal fleet synchronization and cloud back-office automation.', 6)
ON CONFLICT (id) DO NOTHING;

-- 2. COMMUNITY POSTS / TOPICS
CREATE TABLE IF NOT EXISTS public.community_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id TEXT REFERENCES public.community_categories(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  author_name TEXT NOT NULL,
  author_tier TEXT DEFAULT 'Free Merchant',
  author_role TEXT DEFAULT 'merchant',
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  is_pinned BOOLEAN DEFAULT false,
  upvotes_count INT DEFAULT 0,
  replies_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. COMMUNITY COMMENTS / REPLIES
CREATE TABLE IF NOT EXISTS public.community_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES public.community_posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  author_name TEXT NOT NULL,
  author_tier TEXT DEFAULT 'Free Merchant',
  content TEXT NOT NULL,
  is_solution BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. COMMUNITY UPVOTES
CREATE TABLE IF NOT EXISTS public.community_upvotes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  post_id UUID REFERENCES public.community_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES public.community_comments(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_post_vote UNIQUE (user_id, post_id),
  CONSTRAINT unique_comment_vote UNIQUE (user_id, comment_id)
);

-- 5. ROW-LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.community_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_upvotes ENABLE ROW LEVEL SECURITY;

-- Helper function: Check if current auth user is Dev / Admin / Staff
CREATE OR REPLACE FUNCTION public.is_admin_or_dev()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() 
      AND (
        LOWER(role) IN ('admin', 'super_admin', 'dev', 'developer', 'staff', 'owner', 'ops', 'support')
        OR LOWER(COALESCE(auth.jwt() ->> 'email', '')) IN ('info@flexitapapp.com', 'datuljeffrey@gmail.com')
      )
  );
$$;

-- Categories RLS (Anyone can read, only Admin can insert/update/delete)
CREATE POLICY "Public can view categories" 
  ON public.community_categories FOR SELECT USING (true);

CREATE POLICY "Admins can manage categories" 
  ON public.community_categories FOR ALL 
  USING (public.is_admin_or_dev());

-- Posts RLS (Public Read, Authenticated Insert, Author or Admin Delete)
CREATE POLICY "Public can read posts" 
  ON public.community_posts FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create posts" 
  ON public.community_posts FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Author or Admin can update posts" 
  ON public.community_posts FOR UPDATE 
  USING (auth.uid() = user_id OR public.is_admin_or_dev());

CREATE POLICY "Author or Admin can delete posts" 
  ON public.community_posts FOR DELETE 
  USING (auth.uid() = user_id OR public.is_admin_or_dev());

-- Comments RLS (Public Read, Authenticated Insert, Author or Admin Delete)
CREATE POLICY "Public can read comments" 
  ON public.community_comments FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create comments" 
  ON public.community_comments FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Author or Admin can delete comments" 
  ON public.community_comments FOR DELETE 
  USING (auth.uid() = user_id OR public.is_admin_or_dev());

-- Upvotes RLS
CREATE POLICY "Public can read upvotes" 
  ON public.community_upvotes FOR SELECT USING (true);

CREATE POLICY "Authenticated users can insert upvotes" 
  ON public.community_upvotes FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

CREATE POLICY "Users can remove their own upvotes" 
  ON public.community_upvotes FOR DELETE 
  USING (auth.uid() = user_id);

-- Trigger to increment/decrement replies_count on posts automatically
CREATE OR REPLACE FUNCTION public.handle_comment_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.community_posts 
    SET replies_count = replies_count + 1, updated_at = now()
    WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.community_posts 
    SET replies_count = GREATEST(replies_count - 1, 0), updated_at = now()
    WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trigger_update_reply_count ON public.community_comments;
CREATE TRIGGER trigger_update_reply_count
AFTER INSERT OR DELETE ON public.community_comments
FOR EACH ROW EXECUTE FUNCTION public.handle_comment_count();
