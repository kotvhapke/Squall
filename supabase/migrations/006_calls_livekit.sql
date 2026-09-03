-- ============================================================
-- Squall — Calls & LiveKit (006)
-- ============================================================
-- Выполнить после 005_public_servers.sql
-- ============================================================

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 1. CALL SESSIONS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE TABLE IF NOT EXISTS public.call_sessions (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  room_name         TEXT UNIQUE NOT NULL,
  server_id         BIGINT REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id        BIGINT REFERENCES public.channels(id) ON DELETE CASCADE,
  conversation_id   BIGINT REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
  initiated_by      UUID NOT NULL,
  call_type         TEXT NOT NULL DEFAULT 'audio' CHECK (call_type IN ('audio','video')),
  status            TEXT NOT NULL DEFAULT 'ringing' CHECK (status IN ('ringing','connecting','connected','ended','failed')),
  started_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at          TIMESTAMPTZ,
  CHECK (
    (server_id IS NOT NULL AND channel_id IS NOT NULL AND conversation_id IS NULL) OR
    (server_id IS NULL AND channel_id IS NULL AND conversation_id IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS public.call_participants (
  user_id    UUID NOT NULL,
  call_id    BIGINT NOT NULL REFERENCES public.call_sessions(id) ON DELETE CASCADE,
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at    TIMESTAMPTZ,
  muted      BOOLEAN NOT NULL DEFAULT false,
  deafened   BOOLEAN NOT NULL DEFAULT false,
  camera_on  BOOLEAN NOT NULL DEFAULT false,
  screen_sharing BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, call_id)
);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- INDEXES
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CREATE INDEX IF NOT EXISTS idx_call_sessions_room ON public.call_sessions(room_name);
CREATE INDEX IF NOT EXISTS idx_call_sessions_status ON public.call_sessions(status);
CREATE INDEX IF NOT EXISTS idx_call_participants_call ON public.call_participants(call_id);
CREATE INDEX IF NOT EXISTS idx_call_participants_user ON public.call_participants(user_id);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- RLS — ENABLE
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ALTER TABLE public.call_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_participants ENABLE ROW LEVEL SECURITY;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- RLS — POLICIES
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- Call sessions: DM participants see their own, server members see server ones
DROP POLICY IF EXISTS call_sessions_select ON public.call_sessions;
CREATE POLICY call_sessions_select ON public.call_sessions
  FOR SELECT USING (
    (conversation_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.direct_conversation_members dcm
      WHERE dcm.conversation_id = call_sessions.conversation_id AND dcm.user_id = auth.uid()
    ))
    OR
    (server_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.server_members sm
      WHERE sm.server_id = call_sessions.server_id AND sm.user_id = auth.uid()
    ))
  );

DROP POLICY IF EXISTS call_sessions_insert ON public.call_sessions;
CREATE POLICY call_sessions_insert ON public.call_sessions
  FOR INSERT WITH CHECK (auth.uid() = initiated_by);

DROP POLICY IF EXISTS call_sessions_update ON public.call_sessions;
CREATE POLICY call_sessions_update ON public.call_sessions
  FOR UPDATE USING (true) WITH CHECK (true);

-- Call participants: user sees own, others in same call
DROP POLICY IF EXISTS call_participants_select ON public.call_participants;
CREATE POLICY call_participants_select ON public.call_participants
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM public.call_sessions cs
    WHERE cs.id = call_participants.call_id
      AND (
        (cs.conversation_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM public.direct_conversation_members dcm
          WHERE dcm.conversation_id = cs.conversation_id AND dcm.user_id = auth.uid()
        ))
        OR
        (cs.server_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM public.server_members sm
          WHERE sm.server_id = cs.server_id AND sm.user_id = auth.uid()
        ))
      )
  ));

DROP POLICY IF EXISTS call_participants_insert ON public.call_participants;
CREATE POLICY call_participants_insert ON public.call_participants
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS call_participants_update ON public.call_participants;
CREATE POLICY call_participants_update ON public.call_participants
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- GRANTS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

GRANT SELECT, INSERT, UPDATE ON public.call_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.call_participants TO authenticated;
GRANT USAGE ON SEQUENCE public.call_sessions_id_seq TO authenticated;