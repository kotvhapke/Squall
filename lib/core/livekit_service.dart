import 'package:livekit_client/livekit_client.dart';
import 'package:squall/core/supabase_service.dart' as svc;

class LiveKitService {
  static Room? _room;

  static Room get room => _room!;
  static bool get isConnected => _room != null && _room!.connectionState == ConnectionState.connected;

  static LocalParticipant? get _lp => _room?.localParticipant;

  static Future<Room> connectToCall(int callSessionId, {String? roomName}) async {
    if (isConnected) await disconnect();
    final data = await svc.SupabaseService.getLiveKitToken(callSessionId: callSessionId, roomName: roomName);
    _room = await _connect(data['token'] as String, data['roomName'] as String);
    return _room!;
  }

  static Future<Room> connectToVoice(int channelId) async {
    if (isConnected) await disconnect();
    final data = await svc.SupabaseService.getLiveKitToken(voiceChannelId: channelId);
    _room = await _connect(data['token'] as String, data['roomName'] as String);
    return _room!;
  }

  static Future<Room> _connect(String token, String roomName) async {
    // Only one connection at a time
    await disconnect();
    final url = svc.livekitUrl;
    if (!url.startsWith('wss://') && !url.startsWith('ws://')) {
      throw Exception('LiveKit URL must start with wss:// or ws://');
    }
    final room = Room();
    await room.connect(url, token);
    _room = room;
    return room;
  }

  static Future<void> disconnect() async {
    try { await _room?.disconnect(); } catch (_) {}
    _room = null;
  }

  static Future<void> toggleMic() async {
    final lp = _lp;
    if (lp == null) return;
    await lp.setMicrophoneEnabled(!micEnabled);
  }

  static Future<void> toggleCamera() async {
    final lp = _lp;
    if (lp == null) return;
    await lp.setCameraEnabled(!cameraEnabled);
  }

  static Future<void> toggleScreenShare() async {
    final lp = _lp;
    if (lp == null) return;
    await lp.setScreenShareEnabled(!screenShareEnabled);
  }

  static bool get micEnabled {
    final lp = _lp;
    if (lp == null) return false;
    final pubs = lp.trackPublications.values.where((t) => t.source == TrackSource.microphone);
    if (pubs.isEmpty) return false;
    return !pubs.first.muted;
  }

  static bool get cameraEnabled {
    final lp = _lp;
    if (lp == null) return false;
    final pubs = lp.trackPublications.values.where((t) => t.source == TrackSource.camera);
    if (pubs.isEmpty) return false;
    return !pubs.first.muted;
  }

  static bool get screenShareEnabled {
    final lp = _lp;
    if (lp == null) return false;
    final pubs = lp.trackPublications.values.where((t) => t.source == TrackSource.screenShareVideo);
    if (pubs.isEmpty) return false;
    return !pubs.first.muted;
  }

  static List<RemoteParticipant> get remoteParticipants =>
      _room != null ? _room!.remoteParticipants.values.toList() : [];
}