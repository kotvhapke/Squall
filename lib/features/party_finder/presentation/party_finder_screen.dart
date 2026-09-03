import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/shared/widgets/squall_button.dart';
import 'package:squall/shared/widgets/states.dart';

class PartyFinderScreen extends StatefulWidget {
  const PartyFinderScreen({super.key});

  @override
  State<PartyFinderScreen> createState() => _PartyFinderScreenState();
}

class _PartyFinderScreenState extends State<PartyFinderScreen> {
  List<Map<String, dynamic>> _parties = [];
  bool _loading = true;

  // Filters
  String? _filterGame;
  String _filterMode = '';
  String _filterPlatform = '';
  String _filterRank = '';

  static const _modes = ['', 'pvp', 'pve', 'casual', 'competitive'];
  static const _platforms = ['', 'pc', 'playstation', 'xbox', 'nintendo', 'mobile'];
  static const _ranks = ['', 'bronze', 'silver', 'gold', 'platinum', 'diamond', 'legendary'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.searchParties(
        game: _filterGame,
        mode: _filterMode.isEmpty ? null : _filterMode,
        platform: _filterPlatform.isEmpty ? null : _filterPlatform,
        minRank: _filterRank.isEmpty ? null : _filterRank,
      );
      if (mounted) setState(() => _parties = data);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _showCreateDialog() {
    final gameC = TextEditingController();
    final descC = TextEditingController();
    String mode = 'pvp';
    String platform = 'pc';
    String rank = 'gold';
    int maxPlayers = 4;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        backgroundColor: AppColors.darkBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.border)),
        title: const Text('Create Party', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field(gameC, 'Game (e.g. Valorant)', Icons.sports_esports),
              const SizedBox(height: 8),
              _dropdown('Mode', mode, _modes.skip(1).toList(), (v) => setDlgState(() => mode = v!)),
              const SizedBox(height: 8),
              _dropdown('Platform', platform, _platforms.skip(1).toList(), (v) => setDlgState(() => platform = v!)),
              const SizedBox(height: 8),
              _dropdown('Min Rank', rank, _ranks.skip(1).toList(), (v) => setDlgState(() => rank = v!)),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Players: ', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: Slider(
                    value: maxPlayers.toDouble(), min: 1, max: 10, divisions: 9,
                    activeColor: AppColors.electricBlue,
                    label: '$maxPlayers',
                    onChanged: (v) => setDlgState(() => maxPlayers = v.round()),
                  ),
                ),
                Text('$maxPlayers', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              _field(descC, 'Description (optional)', Icons.description),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () async {
            if (gameC.text.trim().isEmpty) return;
            Navigator.pop(ctx);
            try {
              await SupabaseService.createParty(
                game: gameC.text.trim(),
                mode: mode, platform: platform, minRank: rank,
                maxPlayers: maxPlayers, description: descC.text.trim(),
              );
              _load();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            }
          }, child: const Text('Create', style: TextStyle(color: AppColors.electricBlue))),
        ],
      ),
    ));
  }

  void _showFilters() {
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        backgroundColor: AppColors.darkBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.border)),
        title: const Text('Filters', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 280,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Game', labelStyle: TextStyle(color: AppColors.textMuted)),
              style: const TextStyle(color: AppColors.textPrimary),
              controller: TextEditingController(text: _filterGame),
              onChanged: (v) => _filterGame = v.isEmpty ? null : v,
            ),
            const SizedBox(height: 8),
            _dropdown('Mode', _filterMode, _modes, (v) => setDlgState(() => _filterMode = v!)),
            const SizedBox(height: 8),
            _dropdown('Platform', _filterPlatform, _platforms, (v) => setDlgState(() => _filterPlatform = v!)),
            const SizedBox(height: 8),
            _dropdown('Min Rank', _filterRank, _ranks, (v) => setDlgState(() => _filterRank = v!)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () {
            setDlgState(() {
              _filterGame = null;
              _filterMode = '';
              _filterPlatform = '';
              _filterRank = '';
            });
          }, child: const Text('Reset', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            _load();
          }, child: const Text('Apply', style: TextStyle(color: AppColors.electricBlue))),
        ],
      ),
    ));
  }

  Future<void> _joinParty(int partyId) async {
    try {
      await SupabaseService.joinParty(partyId);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined party!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          prefixIcon: Icon(icon, size: 16, color: AppColors.textMuted),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? items.first : value,
          dropdownColor: AppColors.darkBlue,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          items: items.map((s) => DropdownMenuItem(
            value: s.isEmpty ? items.first : s,
            child: Text(s.isEmpty ? 'Any $label' : s[0].toUpperCase() + s.substring(1)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _rankColor(String rank) {
    switch (rank) {
      case 'bronze': return '#CD7F32';
      case 'silver': return '#C0C0C0';
      case 'gold': return '#FFD700';
      case 'platinum': return '#E5E4E2';
      case 'diamond': return '#B9F2FF';
      case 'legendary': return '#FF4500';
      default: return '#FFFFFF';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _header(),
      Expanded(
        child: _loading
            ? const LoadingState()
            : _parties.isEmpty
                ? const EmptyState(icon: Icons.groups_outlined, title: 'No parties found', subtitle: 'Create one or adjust filters')
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.electricBlue,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _parties.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _partyCard(_parties[i]),
                      ),
                    ),
                  ),
      ),
    ]);
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
      child: Row(children: [
        Icon(Icons.groups_outlined, size: 22, color: AppColors.electricBlue),
        const SizedBox(width: 10),
        const Text('Party Finder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const Spacer(),
        GestureDetector(onTap: _showCreateDialog, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.electricBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.electricBlue.withValues(alpha: 0.3))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 14, color: AppColors.electricBlue),
            SizedBox(width: 4),
            Text('Create', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.electricBlue)),
          ]),
        )),
        const SizedBox(width: 8),
        GestureDetector(onTap: _showFilters, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.panelBgOpaque, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_list, size: 14, color: AppColors.textSecondary),
            SizedBox(width: 4),
            Text('Filter', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        )),
      ]),
    );
  }

  Widget _partyCard(Map<String, dynamic> party) {
    final id = party['id'] as int;
    final game = party['game'] as String? ?? 'Unknown';
    final mode = party['mode'] as String? ?? 'pvp';
    final platform = party['platform'] as String? ?? 'pc';
    final rank = party['min_rank'] as String? ?? 'bronze';
    final maxPlayers = party['max_players'] as int? ?? 4;
    final desc = party['description'] as String? ?? '';
    final status = party['status'] as String? ?? 'open';
    final leaderId = party['leader_id'] as String?;
    final isOwn = leaderId == SupabaseService.userId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.serverIconBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            alignment: Alignment.center,
            child: Text(game[0], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.electricBlue)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(game, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text('${mode[0].toUpperCase()}${mode.substring(1)} · ${platform[0].toUpperCase()}${platform.substring(1)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
          _rankBadge(rank),
        ]),
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.people_outline, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text('$status · ?/$maxPlayers', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const Spacer(),
          if (status == 'open')
            isOwn
                ? SizedBox(width: 80, child: SquallButton(label: 'Cancel', onPressed: () async {
                    await SupabaseService.cancelParty(id);
                    _load();
                  }, primary: false, height: 36))
                : SizedBox(width: 80, child: SquallButton(label: 'Join', onPressed: () => _joinParty(id), primary: true, height: 36)),
        ]),
      ]),
    );
  }

  Widget _rankBadge(String rank) {
    final colorHex = _rankColor(rank);
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(rank[0].toUpperCase() + rank.substring(1),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}