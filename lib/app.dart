import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squall/core/theme/app_theme.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/theme/effects.dart';
import 'package:squall/core/settings/settings_provider.dart';
import 'package:squall/core/theme/atmospheric_background.dart';
import 'package:squall/core/supabase_config.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/features/auth/presentation/login_screen.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';
import 'package:squall/shared/widgets/squall_back_button.dart';
import 'package:squall/features/home/presentation/home_screen.dart';
import 'package:squall/features/servers/presentation/server_hub.dart';
import 'package:squall/features/dms/presentation/messages_screen.dart';
import 'package:squall/features/friends/presentation/friends_screen.dart';
import 'package:squall/features/party_finder/presentation/party_finder_screen.dart';
import 'package:squall/features/profile/presentation/profile_screen.dart';
import 'package:squall/core/translations.dart';

class SquallApp extends StatelessWidget {
  const SquallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: Selector<SettingsProvider, Locale>(
        selector: (_, s) => s.locale,
        builder: (context, locale, _) => MaterialApp(
          title: 'Squall',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ru')],
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured) {
      Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = context.watch<SettingsProvider>().reducedEffects;
    if (!SupabaseConfig.isConfigured) {
      return AtmosphericBackground(reducedEffects: reduced, child: Scaffold(body: Center(
        child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppEffects.squallLogo(size: 64), const SizedBox(height: 24),
          const Text('Squall', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          const Text('Supabase not configured.\nAdd config/supabase.local.json with your project keys.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ])),
      )));
    }
    final session = Supabase.instance.client.auth.currentSession;
    return AtmosphericBackground(reducedEffects: reduced, child: session != null ? const AppShell() : LoginScreen(onLogin: () => setState(() {})));
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _navIndex = 0;
  bool _showServerContent = false;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _servers = [];
  Map<String, dynamic>? _selectedServer;
  Map<String, dynamic>? _selectedChannel;
  List<Map<String, dynamic>> _channels = [];

  List<_N> _navItems(BuildContext context) => [
    _N(0, 'Home'.t(context), Icons.home_outlined),
    _N(1, 'Servers'.t(context), Icons.dns_outlined),
    _N(2, 'Friends'.t(context), Icons.people_outline),
    _N(3, 'Messages'.t(context), Icons.chat_outlined),
    _N(4, 'Parties'.t(context), Icons.groups_outlined),
    _N(5, 'Profile'.t(context), Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _profile = await SupabaseService.getProfile();
      _servers = await SupabaseService.getMyServers();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> reloadServers() async {
    try {
      _servers = await SupabaseService.getMyServers();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> reloadProfile() async {
    _profile = await SupabaseService.getProfile();
    if (mounted) setState(() {});
  }

  String _profileName() => _profile?['display_name'] as String? ?? _profile?['username'] as String? ?? 'U';

  Color _statusColor() {
    final s = _profile?['status'] as String?;
    if (s == 'online') return AppColors.voiceActive;
    if (s == 'idle') return AppColors.warning;
    if (s == 'dnd') return AppColors.danger;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Navigation rail
          Container(
            width: 68,
            decoration: BoxDecoration(color: AppColors.background, border: Border(right: BorderSide(color: AppColors.border, width: 1))),
            child: Column(
              children: [
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() => _navIndex = 0),
                  child: Padding(padding: const EdgeInsets.all(10), child: AppEffects.squallLogo(size: 32)),
                ),
                const SizedBox(height: 8),
                Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 18), color: AppColors.border),
                Expanded(child: ListView(children: [
                  ..._navItems(context).map((item) {
                    final selected = _navIndex == item.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _navIndex = item.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180), curve: Curves.easeOutCubic,
                          width: 48, height: 44,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.blue.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: selected ? Border.all(color: AppColors.electricBlue.withValues(alpha: 0.5), width: 1) : null,
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(item.icon, size: 20, color: selected ? AppColors.electricBlue : AppColors.textSecondary),
                            const SizedBox(height: 2),
                            Text(item.label, style: TextStyle(fontSize: 8, color: selected ? AppColors.electricBlue : AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                      ),
                    );
                  }),
                  // Servers in the nav rail (like Discord)
                  if (_servers.isNotEmpty) ...[
                    Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), color: AppColors.border),
                    ..._servers.map((s) {
                      final letter = _serverInitial(s);
                      final name = s['name'] as String? ?? 'Server';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
                        child: Tooltip(
                          message: name,
                          preferBelow: false,
                          verticalOffset: 4,
                          child: GestureDetector(
                            onTap: () => _selectServer(s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180), curve: Curves.easeOutCubic,
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.serverIconBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border, width: 1),
                              ),
                              alignment: Alignment.center,
                              child: Text(letter, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.electricBlue)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ])),
                Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 18), color: AppColors.border),
                // Profile badge
                GestureDetector(
                  onTap: () => setState(() => _navIndex = 5),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Column(children: [
                    Stack(children: [
                      SquallAvatar(
                        name: _profileName(),
                        avatarUrl: _profile?['avatar_url'] as String?,
                        status: _profile?['status'] as String? ?? 'online',
                        size: 36,
                      ),
                      Positioned(bottom: 0, right: 0, child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor(), border: Border.all(color: AppColors.background, width: 2)),
                      )),
                    ]),
                    const SizedBox(height: 3),
                    Text(_profileName().length > 6 ? '${_profileName().substring(0, 6)}…' : _profileName(),
                        style: const TextStyle(fontSize: 9, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(child: _buildPage()),
        ],
      ),
    );
  }

  Widget _buildPage() {
    final locale = context.select<SettingsProvider, Locale>((s) => s.locale);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: KeyedSubtree(key: ValueKey('nav-$_navIndex-${locale.languageCode}'), child: _pageContent()),
    );
  }

  Widget _pageContent() {
    switch (_navIndex) {
      case 0: return _homeTab();
      case 1: return _serversView();
      case 2: return Column(children: [
        _topBar('Friends'.t(context), showBack: _navIndex != 0, onBack: () => setState(() => _navIndex = 0)),
        Expanded(child: FriendsScreen()),
      ]);
      case 3: return Column(children: [
        _topBar('Messages'.t(context), showBack: _navIndex != 0, onBack: () => setState(() => _navIndex = 0)),
        Expanded(child: MessagesScreen()),
      ]);
      case 4: return Column(children: [
        _topBar('Parties'.t(context), showBack: _navIndex != 0, onBack: () => setState(() => _navIndex = 0)),
        Expanded(child: PartyFinderScreen()),
      ]);
      case 5: return Column(children: [
        _topBar('Profile'.t(context), showBack: _navIndex != 0, onBack: () => setState(() => _navIndex = 0)),
        Expanded(child: ProfileScreen(onUpdate: reloadProfile)),
      ]);
      default: return _homeTab();
    }
  }

  Widget _homeTab() {
    return Column(children: [
      _topBar('Squall'),
      Expanded(child: ListView(padding: const EdgeInsets.all(24), children: [
        Text('Your Servers'.t(context), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: _servers.isEmpty
              ? Text('No servers yet'.t(context), style: const TextStyle(color: AppColors.textMuted))
              : ListView.separated(
                  scrollDirection: Axis.horizontal, separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: _servers.length,
                  itemBuilder: (_, i) {
                    final s = _servers[i];
                    return GestureDetector(
                      onTap: () { _selectServer(s); setState(() => _navIndex = 1); },
                      child: Container(width: 60, height: 60,
                          decoration: BoxDecoration(color: AppColors.serverIconBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                          alignment: Alignment.center,
                          child: Text(_serverInitial(s), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.electricBlue))),
                    );
                  },
                ),
        ),
        const SizedBox(height: 32),
        const Text('Welcome to Squall', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Use the navigation on the left'.t(context), style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ])),
    ]);
  }

  Widget _serversView() {
    if (_showServerContent && _selectedServer != null) {
      return HomeScreen(
        key: ValueKey('server-${_selectedServer!['id']}-${_channels.length}'),
        servers: _servers,
        selectedServer: _selectedServer,
        selectedChannel: _selectedChannel,
        channels: _channels,
        onSelectServer: _selectServer,
        onSelectChannel: _selectChannel,
        onReload: _reloadCurrentServer,
        onBack: _backToHub,
      );
    }
    return Column(key: const ValueKey('hub'), children: [
      _topBar('Servers'.t(context), showBack: _navIndex != 0, onBack: () => setState(() => _navIndex = 0)),
      Expanded(
        child: ServerHub(
          key: ValueKey('servers-${_servers.length}'),
          servers: _servers,
          selectedServer: _selectedServer,
          selectedChannel: _selectedChannel,
          channels: _channels,
          onSelectServer: _selectServer,
          onSelectChannel: _selectChannel,
          onReload: reloadServers,
        ),
      ),
    ]);
  }

  void _selectServer(Map<String, dynamic> s) {
    _selectedServer = s;
    _selectedChannel = null;
    _showServerContent = true;
    _loadChannels(s['id'] as int);
    setState(() => _navIndex = 1);
  }

  Future<void> _reloadCurrentServer() async {
    // Force full reload of servers and channels
    try {
      _servers = await SupabaseService.getMyServers();
      if (_selectedServer != null) {
        final sid = _selectedServer!['id'] as int;
        final stillExists = _servers.any((s) => s['id'] == sid);
        if (stillExists) {
          _channels = await SupabaseService.getChannels(sid);
          if (_channels.isNotEmpty && _selectedChannel == null) {
            _selectedChannel = _channels.first;
          }
        } else {
          // Server was deleted
          _selectedServer = null;
          _selectedChannel = null;
          _showServerContent = false;
        }
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _backToHub() async {
    _showServerContent = false;
    _selectedServer = null;
    _selectedChannel = null;
    _channels = [];
    await reloadServers();
    if (mounted) setState(() => _navIndex = 1);
  }

  void _selectChannel(Map<String, dynamic> c) {
    setState(() => _selectedChannel = c);
  }

  Future<void> _loadChannels(int serverId) async {
    try {
      _channels = await SupabaseService.getChannels(serverId);
      if (_channels.isNotEmpty && _selectedChannel == null) {
        _selectedChannel = _channels.first;
      } else if (_channels.isNotEmpty) {
        if (_channels.where((c) => c['id'] == _selectedChannel?['id']).isEmpty) {
          _selectedChannel = _channels.first;
        }
      } else {
        _selectedChannel = null;
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Widget _topBar(String title, {bool showBack = false, VoidCallback? onBack}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: showBack ? 4 : 24, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
      child: Row(children: [
        if (showBack) SquallBackButton(onPressed: onBack ?? () => setState(() => _navIndex = 0)),
        if (!showBack) AppEffects.squallLogo(size: 24),
        if (!showBack) const SizedBox(width: 10),
        if (showBack) const SizedBox(width: 4),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const Spacer(),
      ]),
    );
  }

  String _serverInitial(Map<String, dynamic>? s) {
    if (s == null) return 'S';
    final name = s['name'] as String?;
    if (name == null || name.isEmpty) return 'S';
    return name[0].toUpperCase();
  }
}

class _N {
  final int id;
  final String label;
  final IconData icon;
  const _N(this.id, this.label, this.icon);
}