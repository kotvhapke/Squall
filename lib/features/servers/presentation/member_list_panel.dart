import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';

class MemberListPanel extends StatefulWidget {
  final List<Map<String, dynamic>> members;

  const MemberListPanel({super.key, required this.members});

  @override
  State<MemberListPanel> createState() => _MemberListPanelState();
}

class _MemberListPanelState extends State<MemberListPanel> {
  bool _collapsed = false;

  List<Map<String, dynamic>> get _online =>
      widget.members.where((m) => (m['profile']?['status'] as String?) == 'online').toList();
  List<Map<String, dynamic>> get _offline =>
      widget.members.where((m) => (m['profile']?['status'] as String?) != 'online').toList();

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: _collapsed ? 48 : 232,
      decoration: BoxDecoration(
        color: AppColors.panelBg,
        border: Border(left: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(children: [
        _header(),
        Expanded(child: _collapsed ? const SizedBox() : _body()),
      ]),
    );
  }

  Widget _header() {
    return GestureDetector(
      onTap: () => setState(() => _collapsed = !_collapsed),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
        child: Row(children: [
          Icon(_collapsed ? Icons.people_outline : Icons.groups, size: 18, color: AppColors.electricBlue),
          if (!_collapsed) ...[
            const SizedBox(width: 8),
            const Text('Members', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            Icon(Icons.keyboard_arrow_right, size: 18, color: AppColors.textMuted),
          ],
        ]),
      ),
    );
  }

  Widget _body() {
    return ListView(padding: const EdgeInsets.symmetric(vertical: 4), children: [
      if (_online.isNotEmpty) ...[
        _sectionLabel('ONLINE — ${_online.length}'),
        ..._online.map((m) => _memberTile(m)),
      ],
      if (_offline.isNotEmpty) ...[
        const SizedBox(height: 8),
        _sectionLabel('OFFLINE — ${_offline.length}'),
        ..._offline.map((m) => _memberTile(m)),
      ],
    ]);
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
    );
  }

  Widget _memberTile(Map<String, dynamic> member) {
    final profile = member['profile'] as Map<String, dynamic>? ?? {};
    final role = member['role'] as String? ?? 'member';
    final name = profile['display_name'] as String? ?? profile['username'] as String? ?? 'Unknown';
    final avatarUrl = profile['avatar_url'] as String?;
    final status = profile['status'] as String? ?? 'offline';
    final roleColor = _roleColor(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        SquallAvatar(name: name, avatarUrl: avatarUrl, status: status, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              if (role != 'member')
                Text(role, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: roleColor, letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 1),
            Text('@${profile['username'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
      ]),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'owner': return const Color(0xFFFFB836);
      case 'moderator': return const Color(0xFF36D66E);
      default: return AppColors.textMuted;
    }
  }
}
