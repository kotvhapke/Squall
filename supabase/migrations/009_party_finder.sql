-- ============================================================
-- Squall — Party Finder (009)
-- ============================================================
-- Выполнить после 008_fix_rls.sql в Supabase SQL Editor.
-- ============================================================

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 1. PARTY LISTINGS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE TABLE IF NOT EXISTS public.party_listings (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  game              TEXT NOT NULL,
  game_icon         TEXT,
  mode              TEXT NOT NULL CHECK (mode IN ('pvp','pve','casual','competitive')),
  platform          TEXT NOT NULL CHECK (platform IN ('pc','playstation','xbox','nintendo','mobile')),
  min_rank          TEXT NOT NULL DEFAULT 'bronze' CHECK (min_rank IN ('bronze','silver','gold','platinum','diamond','legendary')),
  max_players       INT NOT NULL CHECK (max_players >= 1 AND max_players <= 10),
  leader_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  description       TEXT NOT NULL DEFAULT '',
  status            TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed','full','cancelled')),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ
);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 2. PARTY MEMBERS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE TABLE IF NOT EXISTS public.party_members (
  party_id    BIGINT NOT NULL REFERENCES public.party_listings(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (party_id, user_id)
);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- INDEXES
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE INDEX IF NOT EXISTS idx_party_listings_status ON public.party_listings(status);
CREATE INDEX IF NOT EXISTS idx_party_listings_game ON public.party_listings(game);
CREATE INDEX IF NOT EXISTS idx_party_listings_created ON public.party_listings(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_party_members_user ON public.party_members(user_id);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- RLS — ENABLE
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ALTER TABLE public.party_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.party_members ENABLE ROW LEVEL SECURITY;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- RLS — POLICIES
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- Anyone authenticated can read open listings
DROP POLICY IF EXISTS party_listings_select ON public.party_listings;
CREATE POLICY party_listings_select ON public.party_listings
  FOR SELECT USING (auth.role() = 'authenticated');

-- Leader can insert
DROP POLICY IF EXISTS party_listings_insert ON public.party_listings;
CREATE POLICY party_listings_insert ON public.party_listings
  FOR INSERT WITH CHECK (auth.uid() = leader_id);

-- Leader can update own listing
DROP POLICY IF EXISTS party_listings_update ON public.party_listings;
CREATE POLICY party_listings_update ON public.party_listings
  FOR UPDATE USING (auth.uid() = leader_id) WITH CHECK (auth.uid() = leader_id);

-- Leader can delete own listing
DROP POLICY IF EXISTS party_listings_delete ON public.party_listings;
CREATE POLICY party_listings_delete ON public.party_listings
  FOR DELETE USING (auth.uid() = leader_id);

-- Party members: user sees own, leader sees all for their party
DROP POLICY IF EXISTS party_members_select ON public.party_members;
CREATE POLICY party_members_select ON public.party_members
  FOR SELECT USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.party_listings
      WHERE id = party_members.party_id AND leader_id = auth.uid()
    )
  );

-- User can insert self
DROP POLICY IF EXISTS party_members_insert ON public.party_members;
CREATE POLICY party_members_insert ON public.party_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS party_members_delete ON public.party_members;
CREATE POLICY party_members_delete ON public.party_members
  FOR DELETE USING (user_id = auth.uid());

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- GRANTS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

GRANT SELECT, INSERT, UPDATE, DELETE ON public.party_listings TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.party_members TO authenticated;
GRANT USAGE ON SEQUENCE public.party_listings_id_seq TO authenticated;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- RPC: join_party (checks slots + status)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE OR REPLACE FUNCTION public.join_party(party_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_leader_id UUID;
  v_max INT;
  v_current INT;
  v_status TEXT;
  v_already BOOLEAN;
BEGIN
  SELECT leader_id, max_players, status INTO v_leader_id, v_max, v_status
  FROM public.party_listings WHERE id = party_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Party not found';
  END IF;
  IF v_status = 'cancelled' THEN
    RAISE EXCEPTION 'Party has been cancelled';
  END IF;
  IF v_leader_id = auth.uid() THEN
    RAISE EXCEPTION 'You are the leader';
  END IF;
  SELECT EXISTS(SELECT 1 FROM public.party_members WHERE party_id = join_party.party_id AND user_id = auth.uid()) INTO v_already;
  IF v_already THEN
    RAISE EXCEPTION 'Already joined';
  END IF;
  SELECT COUNT(*) INTO v_current FROM public.party_members WHERE party_id = join_party.party_id;
  IF v_current >= v_max - 1 THEN
    UPDATE public.party_listings SET status = 'full' WHERE id = party_id;
    RAISE EXCEPTION 'Party is full';
  END IF;
  INSERT INTO public.party_members (party_id, user_id) VALUES (party_id, auth.uid());
  -- Update current status if now full
  IF v_current + 1 >= v_max - 1 THEN
    UPDATE public.party_listings SET status = 'full' WHERE id = party_id;
  END IF;
  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_party(BIGINT) TO authenticated;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- RPC: leave_party
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE OR REPLACE FUNCTION public.leave_party(party_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  DELETE FROM public.party_members WHERE party_id = leave_party.party_id AND user_id = auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not a member';
  END IF;
  -- Re-open if was full
  UPDATE public.party_listings SET status = 'open' WHERE id = party_id AND status = 'full';
  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.leave_party(BIGINT) TO authenticated;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- RPC: get_party_with_members (returns party + member profiles)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE OR REPLACE FUNCTION public.get_party_with_members(party_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'party', row_to_json(pl.*),
    'members', COALESCE(
      (SELECT jsonb_agg(row_to_json(pm.*))
       FROM (
         SELECT p.user_id, pr.username, pr.display_name, pr.avatar_url, pr.status
         FROM public.party_members p
         JOIN public.profiles pr ON pr.id = p.user_id
         WHERE p.party_id = get_party_with_members.party_id
       ) pm),
      '[]'::jsonb
    ),
    'leader', (SELECT row_to_json(lp.*) FROM (
      SELECT id, username, display_name, avatar_url, status
      FROM public.profiles WHERE id = pl.leader_id
    ) lp)
  ) INTO result
  FROM public.party_listings pl
  WHERE pl.id = party_id;
  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_party_with_members(BIGINT) TO authenticated;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- RPC: search_parties (by game, mode, platform, rank)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE OR REPLACE FUNCTION public.search_parties(
  p_game TEXT DEFAULT NULL,
  p_mode TEXT DEFAULT NULL,
  p_platform TEXT DEFAULT NULL,
  p_min_rank TEXT DEFAULT NULL,
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
)
RETURNS SETOF public.party_listings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT pl.*
  FROM public.party_listings pl
  WHERE pl.status = 'open'
    AND (p_game IS NULL OR pl.game ILIKE '%' || p_game || '%')
    AND (p_mode IS NULL OR pl.mode = p_mode)
    AND (p_platform IS NULL OR pl.platform = p_platform)
    AND (p_min_rank IS NULL OR
      CASE pl.min_rank
        WHEN 'bronze' THEN 0
        WHEN 'silver' THEN 1
        WHEN 'gold' THEN 2
        WHEN 'platinum' THEN 3
        WHEN 'diamond' THEN 4
        WHEN 'legendary' THEN 5
      END >=
      CASE p_min_rank
        WHEN 'bronze' THEN 0
        WHEN 'silver' THEN 1
        WHEN 'gold' THEN 2
        WHEN 'platinum' THEN 3
        WHEN 'diamond' THEN 4
        WHEN 'legendary' THEN 5
      END
    )
  ORDER BY pl.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_parties(TEXT, TEXT, TEXT, TEXT, INT, INT) TO authenticated;