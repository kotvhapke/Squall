import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/theme/atmospheric_background.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/features/calls/presentation/call_room.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';
import 'package:squall/shared/widgets/squall_back_button.dart';
import 'package:squall/shared/widgets/states.dart';

class PartyRoom extends StatefulWidget {
  final int partyId;
  final String game;

  const PartyRoom({super.key, required this.partyId, required this.game});

  @override
  State<PartyRoom> createState() => _PartyRoomState();
}

class _PartyRoomState extends State<PartyRoom> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _showOnlyMe = false;
  RealtimeChannel? _realtime;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getPartyMembersWithProfiles(widget.partyId),
        SupabaseService.getPartyMessages(widget.partyId),
      ]);
      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(results[0]);
          _messages = List<Map<String, dynamic>>.from(results[1]);
          _showOnlyMe = _members.isEmpty;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    _realtime = SupabaseService.client.channel('party-messages-${widget.partyId}');
    _realtime!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'party_messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'party_id', value: widget.partyId),
      callback: (payload) async {
        final newId = payload.newRecord['id'];
        final authors = await SupabaseService.getUsersByIds([payload.newRecord['author_id'] as String]);
        if (mounted) {
          setState(() {
            _messages.add({
              'id': newId,
              'party_id': widget.partyId,
              'author_id': payload.newRecord['author_id'],
              'content': payload.newRecord['content'],
              'created_at': payload.newRecord['created_at'],
              'author': authors.isNotEmpty ? authors.first : null,
            });
          });
          _scrollDown();
        }
      },
    );
    _realtime!.subscribe();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.sendPartyMessage(widget.partyId, text);
      _ctrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  void _scrollDown() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  Future<void> _startVoice() async {
    final roomName = 'party_${widget.partyId}';
    final callId = await SupabaseService.findOrCreateCallSession(roomName, null, null, null);
    await SupabaseService.joinCall(callId);
    if (mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallRoom(
        callSessionId: callId,
        roomName: roomName,
        title: '${widget.game} Party',
      )));
    }
  }

  Future<void> _leave() async {
    await SupabaseService.leaveParty(widget.partyId);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _realtime?.unsubscribe();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Column(children: [
        _header(),
        Expanded(child: _loading
            ? const LoadingState()
            : _showOnlyMe
                ? _aloneView()
                : _chatView()),
      ]),
      ),
    );
  }

  Widget _header() {
    final otherCount = _members.where((m) => m['user_id'] != SupabaseService.userId).length;
    final gameInitial = widget.game.isNotEmpty ? widget.game[0].toUpperCase() : 'G';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
      child: Row(children: [
        SquallBackButton(onPressed: _leave),
        const SizedBox(width: 4),
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.blue, AppColors.electricBlue]),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(gameInitial, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.game, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 1),
            Text(otherCount > 0
                ? '$otherCount ${otherCount == 1 ? 'player' : 'players'} in party'
                : 'Waiting for players...',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        )),
        if (otherCount > 0)
          GestureDetector(
            onTap: _startVoice,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.blue, AppColors.electricBlue]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: AppColors.electricBlue.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: -2)],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.headphones, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text('Voice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _aloneView() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.panelBgOpaque, border: Border.all(color: AppColors.border)),
          child: const Icon(Icons.person_outline, size: 48, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        const Text('Никого кроме тебя тут ещё нет', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Когда кто-то присоединится к пати,\nты сможешь начать голосовой чат', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 32),
        SizedBox(width: 160, child: TextButton(
          onPressed: _leave,
          child: const Text('Покинуть пати', style: TextStyle(color: AppColors.danger, fontSize: 13)),
        )),
      ]),
    );
  }

  Widget _chatView() {
    return Column(children: [
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Messages
            Expanded(
              child: _messages.isEmpty
                  ? const Center(child: Text('No messages yet — say hi!', style: TextStyle(color: AppColors.textMuted, fontSize: 13)))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _msgTile(_messages[i]),
                    ),
            ),
            // Member list panel
            Container(
              width: 230,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Text('Members — ${_members.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: _members.map((m) {
                      final isMe = m['user_id'] == SupabaseService.userId;
                      final name = m['display_name'] as String? ?? m['username'] as String? ?? '?';
                      final username = m['username'] as String? ?? '';
                      final avatar = m['avatar_url'] as String?;
                      final status = m['status'] as String? ?? 'offline';
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.blue.withValues(alpha: 0.12) : AppColors.panelBgOpaque,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isMe ? AppColors.electricBlue.withValues(alpha: 0.25) : AppColors.border),
                        ),
                        child: Row(children: [
                          Stack(children: [
                            SquallAvatar(name: name, avatarUrl: avatar, size: 34),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: status == 'online' ? AppColors.voiceActive : AppColors.textMuted,
                                  border: Border.all(color: AppColors.background, width: 1.5),
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(isMe ? 'You' : name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                            Text('@$username', style: const TextStyle(fontSize: 10, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                          ])),
                          if (isMe)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.person_pin, size: 14, color: AppColors.electricBlue),
                            ),
                        ]),
                      );
                    }).toList(),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
      // Input
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 1))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(hintText: 'Message...', hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10)),
              onSubmitted: (_) => _send(),
            )),
            _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue))
                : IconButton(icon: const Icon(Icons.send_rounded, size: 20, color: AppColors.electricBlue), onPressed: _send),
          ]),
        ),
      ),
    ]);
  }

  Widget _msgTile(Map<String, dynamic> msg) {
    final author = msg['author'] as Map<String, dynamic>? ?? {};
    final name = author['display_name'] as String? ?? author['username'] as String? ?? '?';
    final avatar = author['avatar_url'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 4), child: SquallAvatar(name: name, size: 32, avatarUrl: avatar)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(width: 6),
            Text(_fmt(msg['created_at'] as String? ?? ''), style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 2),
          Text(msg['content'] ?? '', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ])),
      ]),
    );
  }

  String _fmt(String iso) {
    try { final dt = DateTime.parse(iso).toLocal(); return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'; }
    catch (_) { return ''; }
  }
}