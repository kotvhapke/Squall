-- ============================================================
-- Squall — Public Servers & Discover (005)
-- ============================================================
-- Выполнить после 004_media_storage.sql
-- ============================================================

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 1. ADD COLUMNS TO servers
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ALTER TABLE public.servers ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'private'
  CHECK (visibility IN ('private', 'public'));

ALTER TABLE public.servers ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT ''
  CHECK (char_length(description) <= 500);

ALTER TABLE public.servers ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'other'
  CHECK (category IN ('gaming', 'study', 'technology', 'art', 'community', 'other'));

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 2. INDEXES
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE INDEX IF NOT EXISTS idx_servers_public ON public.servers(visibility) WHERE visibility = 'public';
CREATE INDEX IF NOT EXISTS idx_servers_category ON public.servers(category) WHERE visibility = 'public';

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 3. SECURE PUBLIC CATALOG VIEW
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP VIEW IF EXISTS public.public_server_catalog;
CREATE VIEW public.public_server_catalog AS
SELECT
  s.id,
  s.name,
  s.icon_url,
  s.description,
  s.category,
  s.created_at,
  (SELECT COUNT(*) FROM public.server_members sm WHERE sm.server_id = s.id)::INT AS member_count
FROM public.servers s
WHERE s.visibility = 'public';

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 4. RLS UPDATES FOR servers
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DROP POLICY IF EXISTS servers_select_member ON public.servers;
CREATE POLICY servers_select_member ON public.servers
  FOR SELECT USING (
    public.is_server_member(id)
    OR visibility = 'public'
  );

DROP POLICY IF EXISTS servers_update_owner ON public.servers;
CREATE POLICY servers_update_owner ON public.servers
  FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 5. GRANTS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

GRANT SELECT ON public.public_server_catalog TO authenticated;