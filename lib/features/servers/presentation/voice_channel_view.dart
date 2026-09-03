import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/feature_flags.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/features/calls/presentation/call_room.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';

class VoiceChannelView extends StatefulWidget {
  final Map<String, dynamic> channel;
  final int serverId;
  final VoidCallback? onReload;

  const VoiceChannelView({super.key, required this.channel, required this.serverId, this.onReload});

  @override
  State<VoiceChannelView> createState() => _VoiceChannelViewState();
}

class _VoiceChannelViewState extends State<VoiceChannelView> {
  bool _loading = false;
  bool _inCall = false;
  Map<String, dynamic>? _activeCall;
  List<Map<String, dynamic>> _participants = [];

  @override
  void initState() {
    super.initState();
    _checkCall();
  }

  Future<void> _checkCall() async {
    try {
      final call = await SupabaseService.getActiveCallForChannel(widget.serverId, widget.channel['id'] as int);
      if (call != null && mounted) {
        final p = await SupabaseService.getCallParticipants(call['id'] as int);
        if (mounted) {
          setState(() {
            _activeCall = call;
            _participants = p;
            _inCall = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _join() async {
    if (!enableCalls) {
      _showError('Calls are not configured');
      return;
    }
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final channelId = widget.channel['id'];
      final chType = widget.channel['type'] ?? 'unknown';
      if (channelId == null) { _showError('Channel ID is missing'); return; }
      final int chId = channelId is int ? channelId : int.tryParse(channelId.toString()) ?? 0;
      if (chId == 0) { _showError('Invalid channel ID'); return; }
      if (chType != 'voice') { _showError('Channel type is "$chType", expected "voice"'); return; }

      final roomName = 'server_${widget.serverId}_channel_$chId';
      final callId = await SupabaseService.findOrCreateCallSession(roomName, widget.serverId, chId, null, 'audio');
      await SupabaseService.joinCall(callId);

      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallRoom(
        roomName: roomName,
        callSessionId: callId,
        title: widget.channel['name'] ?? '',
        onReloadChannels: widget.onReload,
      )));

      if (mounted) {
        try { await SupabaseService.leaveVoiceChannel(widget.serverId, chId); } catch (_) {}
        _checkCall();
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      duration: const Duration(seconds: 5),
      action: m.contains('404') ? SnackBarAction(
        label: 'Refresh', onPressed: () { widget.onReload?.call(); },
      ) : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _header(),
      Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.serverIconBg, border: Border.all(color: AppColors.border)),
              child: Icon(Icons.headphones, size: 40, color: AppColors.voiceActive),
            ),
            const SizedBox(height: 16),
            Text('Voice Channel', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('Join to talk with your squad', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            // Show active participants
            if (_participants.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('In voice:', style: const TextStyle(fontSize: 11, color: AppColors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _participants.map((p) {
                  final profile = p['profile'] as Map<String, dynamic>?;
                  final name = profile?['display_name'] as String? ?? profile?['username'] as String? ?? 'User';
                  final avatar = profile?['avatar_url'] as String?;
                  final status = profile?['status'] as String? ?? 'online';
                  final isSpeaking = p['muted'] == false;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SquallAvatar(name: name, avatarUrl: avatar, status: status, size: 48, isSpeaking: isSpeaking),
                      const SizedBox(height: 4),
                      Text(name.length > 12 ? '${name.substring(0, 10)}…' : name,
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
            if (_loading)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue))
            else
              ElevatedButton.icon(
                onPressed: _join,
                icon: Icon(_inCall ? Icons.call : Icons.call),
                label: Text(_inCall ? 'Join' : (enableCalls ? 'Join Voice' : 'Calls not configured')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electricBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
      child: Row(children: [
        Icon(Icons.headphones, size: 20, color: AppColors.voiceActive),
        const SizedBox(width: 8),
        Text(widget.channel['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.electricBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(_loading ? 'Joining...' : 'Voice', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.electricBlue)),
        ),
      ]),
    );
  }
}