import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/theme/effects.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/shared/widgets/squall_button.dart';
import 'package:squall/features/servers/presentation/channel_list_panel.dart';
import 'package:squall/features/servers/presentation/member_list_panel.dart';
import 'package:squall/features/servers/presentation/text_channel_view.dart';
import 'package:squall/features/servers/presentation/voice_channel_view.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> servers;
  final Map<String, dynamic>? selectedServer;
  final Map<String, dynamic>? selectedChannel;
  final List<Map<String, dynamic>> channels;
  final void Function(Map<String, dynamic>) onSelectServer;
  final void Function(Map<String, dynamic>) onSelectChannel;
  final VoidCallback? onReload;
  final VoidCallback? onBack;

  const HomeScreen({
    super.key,
    this.profile,
    required this.servers,
    this.selectedServer,
    this.selectedChannel,
    required this.channels,
    required this.onSelectServer,
    required this.onSelectChannel,
    this.onReload,
    this.onBack,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (old.selectedServer?['id'] != widget.selectedServer?['id']) {
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    final serverId = widget.selectedServer?['id'];
    if (serverId == null) return;
    try {
      final members = await SupabaseService.getServerMembers(serverId as int);
      if (mounted) setState(() => _members = members);
    } catch (_) {}
  }
  void _showCreateServerDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.darkBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.border)),
      title: const Text('Create Server', style: TextStyle(color: AppColors.textPrimary)),
      content: Container(
        decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Server name', hintStyle: TextStyle(color: AppColors.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () async {
          final name = ctrl.text.trim();
          if (name.isEmpty) return;
          Navigator.pop(ctx);
          try {
            final sid = await SupabaseService.createServer(name);
            await SupabaseService.createChannel(sid, 'general', 'text');
            widget.onReload?.call();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
          }
        }, child: const Text('Create', style: TextStyle(color: AppColors.electricBlue))),
      ],
    ));
  }

  void _showJoinDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.darkBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.border)),
      title: const Text('Join Server', style: TextStyle(color: AppColors.textPrimary)),
      content: Container(
        decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Invite code (16 chars)', hintStyle: TextStyle(color: AppColors.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () async {
          final code = ctrl.text.trim();
          if (code.length < 8) return;
          Navigator.pop(ctx);
          try {
            await SupabaseService.joinServer(code);
            widget.onReload?.call();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        }, child: const Text('Join', style: TextStyle(color: AppColors.electricBlue))),
      ],
    ));
  }

  void _showCreateChannelDialog() {
    final ctrl = TextEditingController();
    String type = 'text';
    final sid = widget.selectedServer!['id'] as int;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: AppColors.darkBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.border)),
        title: const Text('Create Channel', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 280,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Channel name', hintStyle: TextStyle(color: AppColors.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: type,
                  dropdownColor: AppColors.darkBlue,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'text', child: Row(children: [Icon(Icons.tag, size: 16, color: AppColors.textMuted), SizedBox(width: 8), Text('Text')])),
                    DropdownMenuItem(value: 'voice', child: Row(children: [Icon(Icons.headphones, size: 16, color: AppColors.voiceActive), SizedBox(width: 8), Text('Voice')])),
                  ],
                  onChanged: (v) => setDlg(() => type = v!),
                ),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () async {
            final name = ctrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            try {
              await SupabaseService.createChannel(sid, name, type);
              widget.onReload?.call();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            }
          }, child: const Text('Create', style: TextStyle(color: AppColors.electricBlue))),
        ],
      ),
    ));
  }

  void _showDeleteChannelDialog(Map<String, dynamic> ch) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.darkBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.border)),
      title: const Text('Delete Channel', style: TextStyle(color: AppColors.danger)),
      content: Text('Delete #${ch['name']}?', style: const TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          try {
            await SupabaseService.deleteChannel(ch['id'] as int);
            widget.onReload?.call();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        }, child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
      ],
    ));
  }

  void _showServerMenu() {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final pos = RelativeRect.fromRect(
      Rect.fromLTWH(80, 72, 24, 24),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: pos,
      color: AppColors.darkBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      items: [
        _menuItemPopup(Icons.link, 'Create Invite', 'invite'),
        _menuItemPopup(Icons.add, 'Create Channel', 'channel'),
        if (widget.selectedServer!['owner_id'] == SupabaseService.userId)
          _menuItemPopup(Icons.delete_forever, 'Delete Server', 'delete', color: AppColors.danger),
        _menuItemPopup(Icons.logout, 'Leave Server', 'leave'),
      ],
    ).then((value) async {
      if (value == 'invite') {
        try {
          final result = await SupabaseService.createInvite(widget.selectedServer!['id'] as int, 0, null);
          final code = result['code'] as String;
          if (mounted) { Clipboard.setData(ClipboardData(text: code)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invite copied: $code'))); }
        } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
      } else if (value == 'channel') {
        _showCreateChannelDialog();
      } else if (value == 'delete') {
        final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.darkBlue,
          title: const Text('Delete Server?', style: TextStyle(color: AppColors.danger)),
          content: Text('This cannot be undone.', style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
          ],
        ));
        if (confirm == true) {
          try {
            await SupabaseService.deleteServer(widget.selectedServer!['id'] as int);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server deleted')));
              widget.onBack?.call();
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
          }
        }
      } else if (value == 'leave') {
        try { await SupabaseService.leaveServer(widget.selectedServer!['id'] as int); widget.onReload?.call(); }
        catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
      }
    });
  }

  PopupMenuItem<String> _menuItemPopup(IconData icon, String label, String value, {Color? color}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, color: color ?? AppColors.textSecondary, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color ?? AppColors.textPrimary, fontSize: 14)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedServer == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        AppEffects.squallLogo(size: 48),
        const SizedBox(height: 20),
        const Text('No servers yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        SizedBox(width: 220, child: SquallButton(label: 'Create Server', onPressed: _showCreateServerDialog)),
        const SizedBox(height: 10),
        SizedBox(width: 220, child: SquallButton(label: 'Join with Invite', onPressed: _showJoinDialog, primary: false)),
      ]));
    }

    return Row(children: [
      // Server panel (channels)
      Container(
        width: 220,
        decoration: BoxDecoration(color: AppColors.panelBg, border: Border(right: BorderSide(color: AppColors.border, width: 1))),
        child: Column(children: [
          GestureDetector(
            onTap: _showServerMenu,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), width: double.infinity,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
              child: Row(children: [
                Expanded(child: Text(widget.selectedServer!['name'] as String? ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                Icon(Icons.expand_more, size: 20, color: AppColors.textSecondary),
              ]),
            ),
          ),
          Expanded(child: ChannelListPanel(
            channels: widget.channels,
            selectedChannel: widget.selectedChannel,
            onChannelSelected: widget.onSelectChannel,
            serverId: widget.selectedServer!['id'] as int,
            onDeleteChannel: _showDeleteChannelDialog,
            onReload: widget.onReload,
          )),
          // Back to Hub button with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 1))),
            child: GestureDetector(
              onTap: widget.onBack,
              child: const Row(
                children: [
                  Icon(Icons.arrow_back, size: 16, color: AppColors.electricBlue),
                  SizedBox(width: 8),
                  Text('Back to Hub', style: TextStyle(fontSize: 13, color: AppColors.electricBlue, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ]),
      ),
      // Main content
      Expanded(child: widget.selectedChannel == null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppEffects.squallLogo(size: 48),
              const SizedBox(height: 16),
              const Text('No text channels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Create a channel to start chatting', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              SizedBox(width: 200, child: SquallButton(label: 'Create Channel', onPressed: _showCreateChannelDialog, primary: false)),
            ]))
          : _channelContent()),
      // Member list panel (right side, like Discord)
      MemberListPanel(members: _members),
    ]);
  }

  Widget _channelContent() {
    final ch = widget.selectedChannel!;
    if (ch['type'] == 'voice') return VoiceChannelView(channel: ch, serverId: widget.selectedServer!['id'] as int);
    return TextChannelView(channel: ch, serverId: widget.selectedServer!['id'] as int);
  }
}