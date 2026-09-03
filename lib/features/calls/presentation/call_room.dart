import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/core/livekit_service.dart';
import 'package:squall/core/feature_flags.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';
import 'package:squall/shared/widgets/squall_back_button.dart';

class CallRoom extends StatefulWidget {
  final int? callSessionId;
  final int? voiceChannelId;
  final int? serverId;
  final String? roomName;
  final String title;
  final VoidCallback? onReloadChannels;

  const CallRoom({
    super.key,
    this.callSessionId,
    this.voiceChannelId,
    this.serverId,
    this.roomName,
    this.title = '',
    this.onReloadChannels,
  });

  @override
  State<CallRoom> createState() => _CallRoomState();
}

class _CallRoomState extends State<CallRoom> with WidgetsBindingObserver {
  bool _connecting = true;
  String? _error;
  Room? _room;
  bool _micOn = false;
  bool _camOn = false;
  String _localName = '';
  String? _localAvatar;
  String _localStatus = 'online';
  Timer? _timer;
  int _callDuration = 0;
  Map<String, double> _speakingLevels = {};
  String? _viewingScreenShare; // identity of participant whose screen to watch

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!enableCalls) {
      _error = 'Calls are not configured';
      _connecting = false;
      return;
    }
    _loadProfile();
    _connect();
  }

  Future<void> _loadProfile() async {
    final p = await SupabaseService.getProfile();
    if (p != null && mounted) {
      setState(() {
        _localName = p['display_name'] as String? ?? p['username'] as String? ?? 'You';
        _localAvatar = p['avatar_url'] as String?;
        _localStatus = p['status'] as String? ?? 'online';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      LiveKitService.disconnect();
    }
  }

  Future<void> _connect() async {
    setState(() { _connecting = true; _error = null; });
    try {
      if (widget.callSessionId != null) {
        _room = await LiveKitService.connectToCall(widget.callSessionId!, roomName: widget.roomName);
      } else {
        throw Exception('No call target');
      }
      _room!.addListener(_onRoomUpdate);

      await _room!.localParticipant?.setMicrophoneEnabled(true);

      _timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (!mounted) return;
        setState(() {
          _callDuration++;
          for (final p in _room!.remoteParticipants.values) {
            _speakingLevels[p.identity] = p.audioLevel;
          }
        });
      });

      setState(() {
        _connecting = false;
        _micOn = true;
      });
    } catch (e) {
      setState(() {
        _connecting = false;
        _error = e.toString().contains('404') ? 'Channel not found'
            : e.toString().contains('401') ? 'Session expired'
            : e.toString().contains('403') ? 'Access denied'
            : 'Failed to connect: $e';
      });
    }
  }

  void _onRoomUpdate() {
    if (!mounted) return;
    setState(() {
      _micOn = LiveKitService.micEnabled;
      _camOn = LiveKitService.cameraEnabled;
    });
  }

  bool _isSpeaking(String name) {
    final level = _speakingLevels[name];
    return level != null && level > 0.05;
  }

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleMic() async {
    try {
      await LiveKitService.toggleMic();
      _onRoomUpdate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mic error: $e')));
      }
    }
  }

  Future<void> _toggleCamera() async {
    try {
      await LiveKitService.toggleCamera();
      _onRoomUpdate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  Future<void> _toggleScreenShare() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    try {
      await lp.setScreenShareEnabled(!LiveKitService.screenShareEnabled);
      _onRoomUpdate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screen sharing not supported on this platform')),
        );
      }
    }
  }

  Future<void> _leave() async {
    _timer?.cancel();
    LiveKitService.disconnect();
    if (widget.callSessionId != null) {
      await SupabaseService.endCallSession(widget.callSessionId!);
    } else if (widget.voiceChannelId != null && widget.serverId != null) {
      await SupabaseService.leaveVoiceChannel(widget.serverId!, widget.voiceChannelId!);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    LiveKitService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: SquallBackButton(onPressed: _leave),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(_formatDuration(_callDuration),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          if (_viewingScreenShare != null)
            GestureDetector(
              onTap: () => setState(() => _viewingScreenShare = null),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.close, size: 14, color: AppColors.danger),
                  SizedBox(width: 4),
                  Text('Close Stream', style: TextStyle(fontSize: 11, color: AppColors.danger)),
                ]),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.voiceActive.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_connecting ? 'Connecting...' : 'Live',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.voiceActive)),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_connecting) {
      return const Center(child: CircularProgressIndicator(color: AppColors.electricBlue, strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton(onPressed: _connect, child: const Text('Retry', style: TextStyle(color: AppColors.electricBlue))),
          ]),
        ),
      );
    }

    final participants = LiveKitService.remoteParticipants;

    // If viewing someone's screen share, show it fullscreen
    if (_viewingScreenShare != null) {
      final sharingParticipant = participants.where((p) => p.identity == _viewingScreenShare).firstOrNull;
      if (sharingParticipant != null) {
        final screenPub = sharingParticipant.trackPublications.values
            .where((t) => t.source == TrackSource.screenShareVideo).firstOrNull;
        if (screenPub != null) {
          return Column(children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.serverIconBg, borderRadius: BorderRadius.circular(12)),
                child: VideoTrackRenderer(screenPub.track as VideoTrack),
              ),
            ),
            _participantsBar(participants),
            _controls(),
          ]);
        }
      }
      // Fall through if screen share ended
      _viewingScreenShare = null;
    }

    return Column(
      children: [
        Expanded(child: _participantsView(participants)),
        _controls(),
      ],
    );
  }

  Widget _participantsBar(List<RemoteParticipant> participants) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        children: [
          SquallAvatar(name: _localName, avatarUrl: _localAvatar, size: 48, isSpeaking: _isSpeaking(_localName)),
          ...participants.map((p) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SquallAvatar(name: p.identity, size: 48, isSpeaking: _isSpeaking(p.identity)),
          )),
        ],
      ),
    );
  }

  Widget _participantsView(List<RemoteParticipant> participants) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _participantTile(
          name: _localName,
          avatarUrl: _localAvatar,
          status: _localStatus,
          isSpeaking: _isSpeaking(_localName),
          subtitle: _micOn ? null : 'Muted',
          micEnabled: _micOn,
          hasCam: _camOn,
          isScreenSharing: LiveKitService.screenShareEnabled,
          onViewStream: null,
        ),
        const SizedBox(height: 8),
        ...participants.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _participantTile(
            name: p.identity,
            avatarUrl: null,
            status: 'online',
            isSpeaking: _isSpeaking(p.identity),
            subtitle: _isSpeaking(p.identity) ? 'Speaking...' : null,
            micEnabled: p.trackPublications.values.any((t) => t.source == TrackSource.microphone && !t.muted),
            hasCam: p.trackPublications.values.any((t) => t.source == TrackSource.camera),
            isScreenSharing: p.trackPublications.values.any((t) => t.source == TrackSource.screenShareVideo),
            onViewStream: p.trackPublications.values.any((t) => t.source == TrackSource.screenShareVideo)
                ? () => setState(() => _viewingScreenShare = p.identity)
                : null,
          ),
        )),
        if (participants.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Column(children: [
                Icon(Icons.headset_mic, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text('Waiting for others to join...',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _participantTile({
    required String name,
    String? avatarUrl,
    required String status,
    required bool isSpeaking,
    String? subtitle,
    required bool micEnabled,
    required bool hasCam,
    bool isScreenSharing = false,
    VoidCallback? onViewStream,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSpeaking ? AppColors.coldNeon : AppColors.border,
          width: isSpeaking ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        SquallAvatar(
          name: name,
          avatarUrl: avatarUrl,
          status: status,
          size: 52,
          isSpeaking: isSpeaking,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (isScreenSharing) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.monitor, size: 12, color: AppColors.danger),
                      SizedBox(width: 3),
                      Text('Streaming', style: TextStyle(fontSize: 9, color: AppColors.danger)),
                    ]),
                  ),
                ],
              ]),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle, style: TextStyle(fontSize: 12, color: isSpeaking ? AppColors.coldNeon : AppColors.textMuted)),
                ),
            ],
          ),
        ),
        if (onViewStream != null)
          GestureDetector(
            onTap: onViewStream,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.electricBlue.withValues(alpha: 0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.play_arrow, size: 14, color: AppColors.electricBlue),
                SizedBox(width: 4),
                Text('Watch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.electricBlue)),
              ]),
            ),
          ),
        Icon(
          micEnabled ? Icons.mic : Icons.mic_off,
          size: 18,
          color: micEnabled ? AppColors.voiceActive : AppColors.danger,
        ),
        if (hasCam) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.videocam, size: 18, color: AppColors.textMuted)),
      ]),
    );
  }

  Widget _controls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: AppColors.panelBg, border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ctrlBtn(Icons.mic, _micOn, _toggleMic),
          _ctrlBtn(Icons.videocam, _camOn, _toggleCamera),
          _ctrlBtn(Icons.monitor, LiveKitService.screenShareEnabled, _toggleScreenShare),
          _ctrlBtn(Icons.call_end, false, _leave, danger: true),
        ],
      ),
    );
  }

  Widget _ctrlBtn(IconData icon, bool active, VoidCallback onTap, {bool danger = false}) {
    final isMic = icon == Icons.mic;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: danger
              ? AppColors.danger
              : (isMic && !active
                  ? AppColors.danger.withValues(alpha: 0.3)
                  : (active ? AppColors.blue : AppColors.panelBgOpaque)),
          shape: BoxShape.circle,
          border: Border.all(
            color: danger
                ? Colors.transparent
                : (active ? AppColors.electricBlue : AppColors.border),
          ),
        ),
        child: Icon(
          icon,
          size: 24,
          color: danger ? Colors.white : (active ? AppColors.electricBlue : AppColors.textSecondary),
        ),
      ),
    );
  }
}