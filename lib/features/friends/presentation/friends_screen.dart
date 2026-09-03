import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/features/dms/presentation/messages_screen.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';
import 'package:squall/shared/widgets/states.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _blocked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _all = await SupabaseService.getFriends();
      _pending = await SupabaseService.getPendingRequests();
      _blocked = await SupabaseService.getBlockedUsers();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _showAddFriend() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: AppColors.darkBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.border)),
        title: const Text('Add Friend', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 280, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: TextField(
                controller: ctrl, autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: '@username', hintStyle: TextStyle(color: AppColors.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () async {
            final q = ctrl.text.trim().replaceFirst('@', '');
            if (q.isEmpty) return;
            Navigator.pop(ctx);
            try {
              await SupabaseService.sendFriendRequest(q);
              await _load();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent')));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            }
          }, child: const Text('Send Request', style: TextStyle(color: AppColors.electricBlue))),
        ],
      ),
    ));
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
          child: Row(
            children: [
              const Icon(Icons.people_outlined, size: 22, color: AppColors.electricBlue),
              const SizedBox(width: 10),
              const Text('Friends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: _showAddFriend,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.panelBgOpaque, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: const Icon(Icons.person_add_outlined, size: 18, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: AppColors.electricBlue,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.electricBlue,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'All'), Tab(text: 'Online'), Tab(text: 'Pending'), Tab(text: 'Blocked'),
            ],
          ),
        ),
        Expanded(
          child: _loading ? const LoadingState() : TabBarView(
            controller: _tabCtrl,
            children: [
              _list(_all),
              _list(_all.where((u) => (u['status'] as String?) == 'online').toList()),
              _pendingList(),
              _list(_blocked, blocked: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _list(List<Map<String, dynamic>> users, {bool blocked = false}) {
    if (users.isEmpty) return const EmptyState(icon: Icons.people_outlined, title: 'No users', subtitle: '');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        final name = u['display_name'] as String? ?? u['username'] as String? ?? '?';
        final status = u['status'] as String? ?? 'offline';
        return ListTile(
          leading: SquallAvatar(name: name, size: 40),
          title: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          subtitle: Text('@${u['username'] ?? ''}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: status == 'online' ? AppColors.voiceActive : AppColors.textMuted)),
              if (blocked)
                TextButton(onPressed: () async {
                  await SupabaseService.unblockUser(u['id']);
                  await _load();
                }, child: const Text('Unblock', style: TextStyle(fontSize: 11, color: AppColors.electricBlue)))
              else
                TextButton(onPressed: () async {
                  final convId = await SupabaseService.createDirectConversation(u['id']);
                  if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessagesScreen(initialConvId: convId)));
                }, child: const Text('Message', style: TextStyle(fontSize: 11, color: AppColors.electricBlue))),
            ],
          ),
        );
      },
    );
  }

  Widget _pendingList() {
    if (_pending.isEmpty) return const EmptyState(icon: Icons.hourglass_empty_outlined, title: 'No pending requests', subtitle: '');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _pending.length,
      itemBuilder: (_, i) {
        final req = _pending[i];
        final sender = req['sender'] as Map<String, dynamic>? ?? {};
        final name = sender['display_name'] as String? ?? sender['username'] as String? ?? '?';
        final isIncoming = req['receiver_id'] == SupabaseService.userId;
        return ListTile(
          leading: SquallAvatar(name: name, size: 40),
          title: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          subtitle: Text(isIncoming ? 'Wants to be your friend' : 'Request sent', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          trailing: isIncoming
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(onPressed: () async {
                      await SupabaseService.respondToRequest(req['id'] as int, 'accepted');
                      await _load();
                    }, child: const Text('Accept', style: TextStyle(fontSize: 12, color: AppColors.voiceActive))),
                    const SizedBox(width: 4),
                    TextButton(onPressed: () async {
                      await SupabaseService.respondToRequest(req['id'] as int, 'rejected');
                      await _load();
                    }, child: const Text('Decline', style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
                  ],
                )
              : TextButton(onPressed: () async {
                  await SupabaseService.respondToRequest(req['id'] as int, 'cancelled');
                  await _load();
                }, child: const Text('Cancel', style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
        );
      },
    );
  }
}