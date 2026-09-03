import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/shared/widgets/squall_back_button.dart';

class ServerHub extends StatefulWidget {
  final List<Map<String, dynamic>> servers;
  final Map<String, dynamic>? selectedServer;
  final Map<String, dynamic>? selectedChannel;
  final List<Map<String, dynamic>> channels;
  final void Function(Map<String, dynamic>) onSelectServer;
  final void Function(Map<String, dynamic>) onSelectChannel;
  final VoidCallback onReload;

  const ServerHub({
    super.key,
    required this.servers,
    this.selectedServer,
    this.selectedChannel,
    required this.channels,
    required this.onSelectServer,
    required this.onSelectChannel,
    required this.onReload,
  });

  @override
  State<ServerHub> createState() => _ServerHubState();
}

class _ServerHubState extends State<ServerHub> {
  bool _showDiscover = false;
  String _searchQuery = '';

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'gaming';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            return AlertDialog(
              backgroundColor: AppColors.darkBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border)),
              title: Text('Create Server', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 320,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: TextField(
                      controller: nameCtrl, autofocus: true, maxLength: 40,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(hintText: 'Server name', hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14), counterStyle: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: TextField(
                      controller: descCtrl, maxLength: 160, maxLines: 2,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(hintText: 'Description (optional)', hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14), counterStyle: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: category,
                        dropdownColor: AppColors.darkBlue,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        items: ['gaming', 'technology', 'community', 'study', 'art', 'other'].map((c) {
                          return DropdownMenuItem(value: c, child: Row(children: [
                            Icon(Icons.tag, size: 14, color: AppColors.textMuted),
                            SizedBox(width: 8),
                            Text(c),
                          ]));
                        }).toList(),
                        onChanged: (v) => setDlg(() => category = v!),
                      ),
                    ),
                  ),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
                TextButton(onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    final sid = await SupabaseService.createServer(name);
                    await SupabaseService.createChannel(sid, 'general', 'text');
                    widget.onSelectServer({'id': sid, 'name': name, 'owner_id': SupabaseService.userId});
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }, child: Text('Create', style: TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.w600))),
              ],
            );
          },
        );
      },
    );
  }

  void _showJoinDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.darkBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.border)),
      title: Text('Join Server', style: TextStyle(color: AppColors.textPrimary)),
      content: Container(
        decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: TextField(
          controller: ctrl, autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: 'Invite code', hintStyle: TextStyle(color: AppColors.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () async {
          final code = ctrl.text.trim().replaceAll(' ', '');
          if (code.length < 8) return;
          Navigator.pop(ctx);
          try {
            await SupabaseService.joinServer(code);
            widget.onReload();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        }, child: Text('Join', style: TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.w600))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_showDiscover) return _discoverView();

    final filtered = _searchQuery.isEmpty
        ? widget.servers
        : widget.servers.where((s) => (s['name'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Servers', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          SizedBox(height: 4),
          Text('Create a community, discover public servers, or join with an invite.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          SizedBox(height: 24),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => SizedBox(width: 12),
              itemBuilder: (_, i) {
                if (i == 0) return _actionCard('Create Server', Icons.add_circle_outline, 'Start your own community', _showCreateDialog);
                if (i == 1) return _actionCard('Discover', Icons.explore_outlined, 'Find communities to join', () => setState(() => _showDiscover = true));
                return _actionCard('Join with Invite', Icons.link, 'Enter an invite code', _showJoinDialog);
              },
            ),
          ),
          SizedBox(height: 28),
          Row(
            children: [
              Text('Your Servers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Spacer(),
              SizedBox(
                width: 180, height: 32,
                child: Container(
                  decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                  child: TextField(
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search...', hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      prefixIcon: Icon(Icons.search, size: 14, color: AppColors.textMuted),
                      border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (filtered.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: Text('No servers found', style: TextStyle(color: AppColors.textMuted, fontSize: 14))),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: filtered.map((s) => _serverCard(s)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _actionCard(String title, IconData icon, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.panelBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 22, color: AppColors.electricBlue),
            ),
            SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _serverCard(Map<String, dynamic> s) {
    final name = s['name'] as String? ?? 'Server';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    return GestureDetector(
      onTap: () => widget.onSelectServer(s),
      child: Container(
        width: 140,
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.panelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.serverIconBg, border: Border.all(color: AppColors.border)),
              alignment: Alignment.center,
              child: Text(initial, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.electricBlue)),
            ),
            SizedBox(height: 8),
            Tooltip(
              message: name,
              child: Text(name, style: TextStyle(fontSize: 12, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _discoverView() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
          child: Row(
            children: [
              SquallBackButton(onPressed: () => setState(() => _showDiscover = false)),
              SizedBox(width: 8),
              Text('Discover', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Spacer(),
            ],
          ),
        ),
        Expanded(child: _DiscoverList(onJoin: (sid) async {
          widget.onReload();
          setState(() => _showDiscover = false);
        })),
      ],
    );
  }
}

class _DiscoverList extends StatefulWidget {
  final void Function(int serverId) onJoin;
  const _DiscoverList({required this.onJoin});

  @override
  State<_DiscoverList> createState() => _DiscoverListState();
}

class _DiscoverListState extends State<_DiscoverList> {
  List<Map<String, dynamic>> _servers = [];
  bool _loading = true;
  String _category = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _servers = await SupabaseService.getPublicCatalog(category: _category == 'all' ? null : _category, search: _searchCtrl.text);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search...', hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      prefixIcon: Icon(Icons.search, size: 14, color: AppColors.textMuted),
                      border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    dropdownColor: AppColors.darkBlue,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    items: ['all', 'gaming', 'study', 'technology', 'art', 'community'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) { setState(() => _category = v!); _load(); },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: AppColors.electricBlue, strokeWidth: 2))
              : _servers.isEmpty
                  ? Center(child: Text('No public servers found', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _servers.length,
                      itemBuilder: (_, i) => _card(_servers[i]),
                    ),
        ),
      ],
    );
  }

  Widget _card(Map<String, dynamic> s) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.panelBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.serverIconBg, border: Border.all(color: AppColors.border)),
            alignment: Alignment.center,
            child: Text(((s['name'] as String? ?? 'S')[0]).toUpperCase(), style: TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.w700)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('${s['member_count'] ?? 0} members · ${s['category'] ?? ''}', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                final code = await SupabaseService.createInvite(s['id'] as int, 1, null);
                await SupabaseService.joinServer(code['code'] as String);
                widget.onJoin(s['id'] as int);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: Text('Join', style: TextStyle(color: AppColors.electricBlue, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}