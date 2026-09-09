import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';
import 'package:squall/shared/widgets/squall_button.dart';
import 'package:squall/shared/widgets/squall_back_button.dart';
import 'package:squall/shared/widgets/states.dart';

class ServerSettingsScreen extends StatefulWidget {
  final int serverId;
  final String serverName;
  final String? ownerId;
  const ServerSettingsScreen({super.key, required this.serverId, required this.serverName, this.ownerId});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _nameCtrl = TextEditingController();
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _nameCtrl.text = widget.serverName;
    _isOwner = widget.ownerId == SupabaseService.userId;
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _members = await SupabaseService.getServerMembers(widget.serverId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await SupabaseService.renameServer(widget.serverId, name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server renamed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _changeRole(Map<String, dynamic> member, String role) async {
    final userId = member['user_id'] as String;
    final name = member['profile']?['display_name'] ?? member['profile']?['username'] ?? 'User';
    try {
      await SupabaseService.setMemberRole(widget.serverId, userId, role);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name is now $role')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'owner': return const Color(0xFFFFB836);
      case 'moderator': return const Color(0xFF36D66E);
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        _header(),
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
              Tab(text: 'Overview'), Tab(text: 'Roles'), Tab(text: 'Members'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const LoadingState()
              : _isOwner
                  ? TabBarView(controller: _tabCtrl, children: [_overview(), _rolesTab(), _membersTab()])
                  : _membersOnlyView(),
        ),
      ]),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
      child: Row(children: [
        SquallBackButton(onPressed: () => Navigator.pop(context)),
        const SizedBox(width: 4),
        Icon(Icons.settings_outlined, size: 22, color: AppColors.electricBlue),
        const SizedBox(width: 10),
        Expanded(child: Text('Server Settings', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      ]),
    );
  }

  Widget _membersOnlyView() {
    return TabBarView(controller: _tabCtrl, children: [_overview(), _membersTab()]);
  }

  Widget _section(String title) {
    return Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8));
  }

  Widget _overview() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      _section('SERVER NAME'),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: _nameCtrl,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12)),
        ),
      ),
      const SizedBox(height: 12),
      if (_isOwner)
        SizedBox(width: 160, child: SquallButton(label: 'Save Name', onPressed: _saveName, height: 40))
      else
        const Text('Only the server owner can edit settings.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      const SizedBox(height: 28),
      _section('ROLES'),
      const SizedBox(height: 8),
      _roleCard(Icons.star_outline, 'Owner', const Color(0xFFFFB836), 'Full control — manage roles, delete server'),
      _roleCard(Icons.shield_outlined, 'Moderator', const Color(0xFF36D66E), 'Can create channels, invites, delete messages'),
      _roleCard(Icons.person_outline, 'Member', AppColors.textMuted, 'Can chat and call'),
    ]);
  }

  Widget _roleCard(IconData icon, String name, Color color, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.panelBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ])),
      ]),
    );
  }

  Widget _rolesTab() {
    // Roles overview + assign to members
    final online = _members.where((m) => (m['profile']?['status'] as String?) == 'online').toList();
    final offline = _members.where((m) => (m['profile']?['status'] as String?) != 'online').toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _section('ASSIGN ROLES'),
      const SizedBox(height: 8),
      if (online.isNotEmpty) ...[
        _section('ONLINE'),
        ...online.map((m) => _assignTile(m)),
      ],
      const SizedBox(height: 8),
      if (offline.isNotEmpty) ...[
        _section('OFFLINE'),
        ...offline.map((m) => _assignTile(m)),
      ],
    ]);
  }

  Widget _assignTile(Map<String, dynamic> member) {
    final profile = member['profile'] as Map<String, dynamic>? ?? {};
    final role = member['role'] as String? ?? 'member';
    final name = profile['display_name'] as String? ?? profile['username'] as String? ?? 'Unknown';
    final avatarUrl = profile['avatar_url'] as String?;
    final isOwner = role == 'owner';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.panelBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        SquallAvatar(name: name, avatarUrl: avatarUrl, status: profile['status'] ?? 'offline', size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text('@${profile['username'] ?? ''}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ]),
        ),
        if (isOwner)
          const Text('Owner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFFB836)))
        else
          _roleDropdown(member, role),
      ]),
    );
  }

  Widget _roleDropdown(Map<String, dynamic> member, String current) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          dropdownColor: AppColors.darkBlue,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _roleColor(current)),
          items: const [
            DropdownMenuItem(value: 'member', child: Text('Member', style: TextStyle(color: AppColors.textPrimary))),
            DropdownMenuItem(value: 'moderator', child: Text('Moderator', style: TextStyle(color: Color(0xFF36D66E)))),
          ],
          onChanged: (v) {
            if (v != null && v != current) _changeRole(member, v);
          },
        ),
      ),
    );
  }

  Widget _membersTab() {
    final online = _members.where((m) => (m['profile']?['status'] as String?) == 'online').toList();
    final offline = _members.where((m) => (m['profile']?['status'] as String?) != 'online').toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (online.isNotEmpty) ...[
        _section('ONLINE — ${online.length}'),
        ...online.map((m) => _memberTile(m)),
      ],
      if (offline.isNotEmpty) ...[
        const SizedBox(height: 8),
        _section('OFFLINE — ${offline.length}'),
        ...offline.map((m) => _memberTile(m)),
      ],
    ]);
  }

  Widget _memberTile(Map<String, dynamic> member) {
    final profile = member['profile'] as Map<String, dynamic>? ?? {};
    final role = member['role'] as String? ?? 'member';
    final name = profile['display_name'] as String? ?? profile['username'] as String? ?? 'Unknown';
    final avatarUrl = profile['avatar_url'] as String?;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.panelBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        SquallAvatar(name: name, avatarUrl: avatarUrl, status: profile['status'] ?? 'offline', size: 34),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text('@${profile['username'] ?? ''}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: _roleColor(role).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _roleColor(role))),
        ),
      ]),
    );
  }
}
