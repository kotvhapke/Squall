import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/feature_flags.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/features/calls/presentation/call_room.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';
import 'package:squall/shared/widgets/squall_button.dart';
import 'package:squall/shared/widgets/squall_panel.dart';
import 'package:squall/shared/widgets/states.dart';

class MessagesScreen extends StatefulWidget {
  final int? initialConvId;
  const MessagesScreen({super.key, this.initialConvId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _convs = [];
  bool _loading = true;
  int? _selectedConvId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _convs = await SupabaseService.getMyConversations();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
          child: Row(
            children: [
              const Icon(Icons.chat_outlined, size: 22, color: AppColors.electricBlue),
              const SizedBox(width: 10),
              const Text('Messages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const LoadingState()
              : _convs.isEmpty
                  ? const EmptyState(icon: Icons.chat_outlined, title: 'No conversations', subtitle: 'Add a friend to start chatting')
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _convs.length,
                      itemBuilder: (_, i) => _convTile(_convs[i]),
                    ),
        ),
      ],
    );
  }

  Widget _convTile(Map<String, dynamic> conv) {
    final other = conv['other_user'] as Map<String, dynamic>? ?? {};
    final name = other['display_name'] as String? ?? other['username'] as String? ?? 'Unknown';
    final last = conv['last_message'] as Map<String, dynamic>?;
    final convId = conv['conversation_id'] as int;
    final selected = _selectedConvId == convId;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedConvId = convId);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => _DmChat(
          conversationId: convId,
          otherUser: other,
          onBack: () => _load(),
        )));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: selected ? BoxDecoration(color: AppColors.panelBgOpaque, border: Border(left: BorderSide(color: AppColors.electricBlue, width: 2))) : null,
        child: Row(
          children: [
            Stack(
              children: [
                SquallAvatar(name: name, size: 42),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (other['status'] as String?) == 'online' ? AppColors.voiceActive : AppColors.textMuted,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    last?['content'] as String? ?? 'No messages yet',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DmChat extends StatefulWidget {
  final int conversationId;
  final Map<String, dynamic> otherUser;
  final VoidCallback? onBack;

  const _DmChat({required this.conversationId, required this.otherUser, this.onBack});

  @override
  State<_DmChat> createState() => _DmChatState();
}

class _DmChatState extends State<_DmChat> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _blocked = false;
  RealtimeChannel? _realtime;

  @override
  void initState() {
    super.initState();
    _load();
    _checkBlocked();
    _subscribe();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _messages = await SupabaseService.getDirectMessages(widget.conversationId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());
  }

  Future<void> _checkBlocked() async {
    final b = await SupabaseService.isBlocked(widget.otherUser['id']);
    if (mounted) setState(() => _blocked = b);
  }

  void _subscribe() {
    _realtime = SupabaseService.subscribeDirectMessages(widget.conversationId, (msg) {
      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollDown();
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.sendDirectMessage(widget.conversationId, text);
      _ctrl.clear();
      _scrollDown();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  void _scrollDown() {
    if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _startCall(String type) async {
    final roomName = 'dm_${widget.conversationId}';
    final callId = await SupabaseService.createCallSession(roomName, null, null, widget.conversationId, type);
    await SupabaseService.joinCall(callId);
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallRoom(
        callSessionId: callId,
        title: 'Call',
      )));
    }
  }

  void _showProfilePopover() {
    final user = widget.otherUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBlue,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _ProfileCard(user: user, onBlock: () async {
        Navigator.pop(ctx);
        if (_blocked) {
          await SupabaseService.unblockUser(user['id']);
        } else {
          await SupabaseService.blockUser(user['id']);
        }
        await _checkBlocked();
      }),
    );
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
    final name = widget.otherUser['display_name'] as String? ?? widget.otherUser['username'] as String? ?? 'Unknown';
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
            child: Row(
              children: [
                GestureDetector(onTap: () { Navigator.pop(context); widget.onBack?.call(); }, child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                GestureDetector(onTap: _showProfilePopover, child: SquallAvatar(name: name, size: 36)),
                const SizedBox(width: 10),
                Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                if (_blocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Blocked', style: TextStyle(fontSize: 11, color: AppColors.danger)),
                  ),
                if (!_blocked && enableCalls) ...[
                  IconButton(icon: const Icon(Icons.call, size: 20, color: AppColors.voiceActive), onPressed: () => _startCall('audio')),
                  IconButton(icon: const Icon(Icons.videocam, size: 20, color: AppColors.textSecondary), onPressed: () => _startCall('video')),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading ? const LoadingState() : _messages.isEmpty
                ? const EmptyState(icon: Icons.chat_outlined, title: 'No messages', subtitle: 'Send a message to start')
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _msgTile(_messages[i]),
                  ),
          ),
          if (!_blocked)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 1))),
              child: SquallPanel(
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(hintText: 'Message...', hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue))
                      : IconButton(icon: const Icon(Icons.send_rounded, size: 20, color: AppColors.electricBlue), onPressed: _send),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _msgTile(Map<String, dynamic> msg) {
    final author = msg['author'] as Map<String, dynamic>? ?? {};
    final isMe = author['id'] != null && author['id'] == SupabaseService.userId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SquallAvatar(name: author['display_name'] ?? author['username'] ?? '?', size: 28, avatarUrl: author['avatar_url'] as String?),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? AppColors.blue.withValues(alpha: 0.25) : AppColors.panelBgOpaque,
                borderRadius: BorderRadius.circular(12).copyWith(
                  bottomRight: isMe ? Radius.zero : null,
                  bottomLeft: !isMe ? Radius.zero : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(author['display_name'] ?? author['username'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.electricBlue)),
                    ),
                  Text(msg['content'] ?? '', style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_fmt(msg['created_at'] as String? ?? ''), style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                      if (isMe)
                        GestureDetector(
                          onTap: () async {
                            await SupabaseService.softDeleteDirectMessage(msg['id'] as int);
                            setState(() => _messages.removeWhere((m) => m['id'] == msg['id']));
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(Icons.delete_outline, size: 12, color: AppColors.textMuted),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(String iso) {
    try { final dt = DateTime.parse(iso).toLocal(); return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'; }
    catch (_) { return ''; }
  }
}

class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onBlock;

  const _ProfileCard({required this.user, this.onBlock});

  @override
  Widget build(BuildContext context) {
    final name = user['display_name'] as String? ?? user['username'] as String? ?? 'Unknown';
    final username = user['username'] as String? ?? '';
    final status = user['status'] as String? ?? 'offline';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SquallAvatar(name: name, size: 72),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('@$username', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: status == 'online' ? AppColors.voiceActive.withValues(alpha: 0.15) : AppColors.panelBgOpaque,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(status, style: TextStyle(fontSize: 11, color: status == 'online' ? AppColors.voiceActive : AppColors.textMuted)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SquallButton(label: 'Message', onPressed: () => Navigator.pop(context), height: 38, fullWidth: false),
              const SizedBox(width: 10),
              SquallButton(label: 'Block', onPressed: onBlock, primary: false, height: 38, fullWidth: false),
            ],
          ),
        ],
      ),
    );
  }
}