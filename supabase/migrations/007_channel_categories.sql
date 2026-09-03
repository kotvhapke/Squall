-- ============================================================
-- Squall — Channel Categories (007)
-- ============================================================
-- Выполнить после 006_calls_livekit.sql
-- ============================================================

ALTER TABLE public.channels ADD COLUMN IF NOT EXISTS category TEXT DEFAULT '';
ALTER TABLE public.channels DROP CONSTRAINT IF EXISTS channels_category_check;
ALTER TABLE public.channels ADD CONSTRAINT channels_category_check
  CHECK (char_length(category) <= 50 OR category = '');

CREATE INDEX IF NOT EXISTS idx_channels_category ON public.channels(server_id, category, position);