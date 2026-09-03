import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/theme/effects.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';
import 'package:squall/shared/widgets/squall_panel.dart';
import 'package:squall/shared/widgets/states.dart';

class TextChannelView extends StatefulWidget {
  final Map<String, dynamic> channel;
  final int serverId;

  const TextChannelView({super.key, required this.channel, required this.serverId});

  @override
  State<TextChannelView> createState() => _TextChannelViewState();
}

class _TextChannelViewState extends State<TextChannelView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _realtime;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribe();
  }

  @override
  void didUpdateWidget(TextChannelView old) {
    super.didUpdateWidget(old);
    if (old.channel['id'] != widget.channel['id']) {
      _realtime?.unsubscribe();
      _loading = true;
      _messages = [];
      _error = null;
      _loadMessages();
      _subscribe();
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      _messages = await SupabaseService.getMessages(widget.channel['id']);
    } catch (e) {
      _error = 'Failed to load messages';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _subscribe() {
    _realtime = SupabaseService.subscribeMessages(widget.channel['id'], (msg) {
      if (mounted) setState(() => _messages.add(msg));
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.sendMessage(widget.channel['id'], text);
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  void dispose() {
    _realtime?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header(),
        Expanded(
          child: _loading
              ? const LoadingState()
              : _error != null
                  ? ErrorState(message: _error!)
                  : _messages.isEmpty
                      ? _emptyChannel()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) => _messageTile(_messages[i]),
                        ),
        ),
        _inputBar(),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.tag, size: 20, color: AppColors.electricBlue),
          const SizedBox(width: 8),
          Text('# ${widget.channel['name'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _messageTile(Map<String, dynamic> msg) {
    final author = msg['author'] as Map<String, dynamic>? ?? {};
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SquallAvatar(name: author['display_name'] ?? author['username'] ?? '?', size: 36),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(author['display_name'] ?? author['username'] ?? 'Unknown', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Text(_formatTime(msg['created_at'] as String? ?? ''), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(msg['content'] ?? '', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyChannel() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppEffects.squallLogo(size: 48),
          const SizedBox(height: 16),
          const Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Send a message to start the conversation', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SquallPanel(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.textMuted),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            if (_sending)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue))
            else
              IconButton(
                icon: const Icon(Icons.send_rounded, size: 20, color: AppColors.electricBlue),
                onPressed: _send,
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
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}