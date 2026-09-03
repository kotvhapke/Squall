import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';
import 'package:squall/shared/widgets/squall_button.dart';
import 'package:squall/shared/widgets/squall_panel.dart';
import 'package:squall/shared/widgets/states.dart';

class DmsScreen extends StatefulWidget {
  const DmsScreen({super.key});

  @override
  State<DmsScreen> createState() => _DmsScreenState();
}

class _DmsScreenState extends State<DmsScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _conversations = await SupabaseService.getMyConversations();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _showNewDmDialog() {
    final ctrl = TextEditingController();
    Map<String, dynamic>? found;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppColors.darkBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.border)),
        title: const Text('New Message', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Search by username',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (v) async {
                    if (v.trim().length < 2) { setDialogState(() => found = null); return; }
                    final results = await SupabaseService.searchUsers(v.trim());
                    if (results.isNotEmpty && results[0]['id'] != SupabaseService.userId) {
                      setDialogState(() => found = results[0]);
                    } else {
                      setDialogState(() => found = null);
                    }
                  },
                ),
              ),
              if (found != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.panelBgOpaque, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      SquallAvatar(name: found!['display_name'] ?? found!['username'] ?? '?', size: 36),
                      const SizedBox(width: 10),
                      Expanded(child: Text(found!['display_name'] ?? found!['username'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: found == null ? null : () async {
            Navigator.pop(ctx);
            try {
              await SupabaseService.createDirectConversation(found!['id']);
              await _load();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            }
          }, child: const Text('Start Chat', style: TextStyle(color: AppColors.electricBlue))),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header(),
        Expanded(
          child: _loading
              ? const LoadingState()
              : _conversations.isEmpty
                  ? const EmptyState(icon: Icons.chat_outlined, title: 'No direct messages', subtitle: 'Start a conversation with a friend')
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _conversations.length,
                      itemBuilder: (_, i) => _dmTile(_conversations[i]),
                    ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
      child: Row(
        children: [
          Icon(Icons.chat_outlined, size: 22, color: AppColors.electricBlue),
          const SizedBox(width: 10),
          const Text('Direct Messages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: _showNewDmDialog,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.panelBgOpaque, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border, width: 1)),
              child: Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dmTile(Map<String, dynamic> conv) {
    final other = conv['other_user'] as Map<String, dynamic>? ?? {};
    final name = other['display_name'] as String? ?? other['username'] as String? ?? 'Unknown';
    final last = conv['last_message'] as Map<String, dynamic>?;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _DmChatScreen(
        conversationId: conv['conversation_id'] as int,
        otherUser: other,
      ))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            SquallAvatar(name: name, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      const Spacer(),
                      if (last != null)
                        Text(_formatTime(last['created_at'] as String? ?? ''), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
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

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) { return ''; }
  }
}

class _DmChatScreen extends StatefulWidget {
  final int conversationId;
  final Map<String, dynamic> otherUser;

  const _DmChatScreen({required this.conversationId, required this.otherUser});

  @override
  State<_DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends State<_DmChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _realtime;
  bool _blocked = false;

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
  }

  Future<void> _checkBlocked() async {
    final b = await SupabaseService.isBlocked(widget.otherUser['id']);
    if (mounted) setState(() => _blocked = b);
  }

  void _subscribe() {
    _realtime = SupabaseService.subscribeDirectMessages(widget.conversationId, (msg) {
      if (mounted) setState(() => _messages.add(msg));
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.sendDirectMessage(widget.conversationId, text);
      _ctrl.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _deleteMsg(int id) async {
    await SupabaseService.softDeleteDirectMessage(id);
    setState(() => _messages.removeWhere((m) => m['id'] == id));
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
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textSecondary)),
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
                    itemBuilder: (_, i) => _messageTile(_messages[i]),
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

  Widget _messageTile(Map<String, dynamic> msg) {
    final author = msg['author'] as Map<String, dynamic>? ?? {};
    final isMe = author['id'] == SupabaseService.userId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            SquallAvatar(name: author['display_name'] ?? author['username'] ?? '?', size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? AppColors.blue.withValues(alpha: 0.3) : AppColors.panelBgOpaque,
                borderRadius: BorderRadius.circular(12).copyWith(
                  bottomRight: isMe ? Radius.zero : null,
                  bottomLeft: !isMe ? Radius.zero : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg['content'] ?? '', style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_formatTime(msg['created_at'] as String? ?? ''), style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                      if (isMe)
                        GestureDetector(
                          onTap: () => _deleteMsg(msg['id'] as int),
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

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
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
    final isMe = user['id'] == SupabaseService.userId;
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
          if (!isMe) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SquallButton(label: 'Message', onPressed: () => Navigator.pop(context), height: 38, fullWidth: false),
                const SizedBox(width: 10),
                SquallButton(label: 'Block', onPressed: onBlock, primary: false, height: 38, fullWidth: false),
              ],
            ),
          ],
        ],
      ),
    );
  }
}