import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { AccessToken } from "https://esm.sh/livekit-server-sdk@2.12.0";

const LIVEKIT_URL = Deno.env.get("LIVEKIT_URL")!;
const LIVEKIT_API_KEY = Deno.env.get("LIVEKIT_API_KEY")!;
const LIVEKIT_API_SECRET = Deno.env.get("LIVEKIT_API_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders, status: 204 });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  const authHeader = req.headers.get("authorization")?.replace("Bearer ", "");
  if (!authHeader) return new Response(JSON.stringify({ error: "Missing authorization" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
  const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader);
  if (authError || !user) return new Response(JSON.stringify({ error: "Invalid or expired token" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  let body;
  try { body = await req.json(); } catch { return new Response(JSON.stringify({ error: "Invalid JSON" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }

  const callSessionId = body?.call_session_id;
  const voiceChannelId = body?.voice_channel_id;
  let roomName = body?.room_name;

  // Если room_name уже передан в теле — используем его напрямую
  if (!roomName && callSessionId) {
    const { data: call } = await supabase.from("calls").select("server_id, channel_id, conversation_id").eq("id", callSessionId).maybeSingle();
    if (call) {
      roomName = call.conversation_id ? `dm_${call.conversation_id}` : `server_${call.server_id}_channel_${call.channel_id}`;
    }
  } else if (!roomName && voiceChannelId) {
    const { data: ch } = await supabase.from("channels").select("server_id").eq("id", voiceChannelId).maybeSingle();
    if (ch) roomName = `server_${ch.server_id}_channel_${voiceChannelId}`;
  }

  if (!roomName) return new Response(JSON.stringify({ error: "Could not determine room" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, { identity: user.id, ttl: "10m" });
  at.addGrant({ roomJoin: true, room: roomName, canPublish: true, canSubscribe: true });
  const token = await at.toJwt();

  return new Response(JSON.stringify({ token, roomName, identity: user.id }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
});