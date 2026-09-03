import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/supabase_service.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';
import 'package:squall/shared/widgets/states.dart';
import 'package:squall/features/settings/presentation/settings_screen.dart';
import 'package:squall/shared/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  final VoidCallback? onUpdate;
  const ProfileScreen({super.key, this.userId, this.onUpdate});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _isOwn = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = widget.userId != null
        ? await SupabaseService.getProfileById(widget.userId!)
        : await SupabaseService.getProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isOwn = widget.userId == null || widget.userId == SupabaseService.userId;
        _loading = false;
      });
    }
  }

  void _pickAvatar() async {
    if (!_isOwn) return;
    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await pickImageFile();
      if (bytes != null) {
        final url = await SupabaseService.uploadAvatar(bytes);
        if (url != null && mounted) {
          setState(() => _profile?['avatar_url'] = url);
          widget.onUpdate?.call();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showEditDialog() {
    final nameCtrl = TextEditingController(text: _profile?['display_name'] as String? ?? '');
    final usernameCtrl = TextEditingController(text: _profile?['username'] as String? ?? '');
    String status = _profile?['status'] as String? ?? 'online';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        backgroundColor: AppColors.darkBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.border)),
        title: const Text('Edit Profile', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _editField(nameCtrl, 'Display Name', Icons.person_outline),
              const SizedBox(height: 10),
              _editField(usernameCtrl, 'Username', Icons.tag),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: status,
                    dropdownColor: AppColors.darkBlue,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    items: ['online', 'idle', 'dnd', 'offline'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setDlgState(() => status = v!),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () async {
            final newStatus = status;
            Navigator.pop(ctx);
            try {
              await SupabaseService.updateProfile(displayName: nameCtrl.text, username: usernameCtrl.text, status: newStatus);
              if (mounted) {
                setState(() {
                  _profile?['display_name'] = nameCtrl.text;
                  _profile?['username'] = usernameCtrl.text;
                  _profile?['status'] = newStatus;
                });
                widget.onUpdate?.call();
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            }
          }, child: const Text('Save', style: TextStyle(color: AppColors.electricBlue))),
        ],
      ),
    ));
  }

  Widget _editField(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingState());
    final p = _profile;
    if (p == null) return const Scaffold(body: ErrorState(message: 'User not found'));

    final name = p['display_name'] as String? ?? p['username'] as String? ?? 'User';
    final username = p['username'] as String? ?? '';
    final avatarUrl = p['avatar_url'] as String?;
    final status = p['status'] as String? ?? 'offline';
    final createdAt = p['created_at'] as String? ?? '';

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      SquallAvatar(name: name, avatarUrl: avatarUrl, status: status, size: 80),
                      if (_isOwn)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.electricBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.background, width: 2),
                            ),
                            child: _uploadingAvatar
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    if (_isOwn) ...[
                      GestureDetector(
                        onTap: _showEditDialog,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.edit_outlined, size: 18, color: AppColors.electricBlue),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.settings_outlined, size: 18, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text('@$username', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
          Expanded(child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _infoRow(Icons.person_outline, 'Display Name', name),
              _infoRow(Icons.tag, 'Username', '@$username'),
              _infoRow(Icons.circle_outlined, 'Status', status),
              _infoRow(Icons.cake_outlined, 'Member Since', _formatDate(createdAt)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _infoRow(IconData? icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 18, color: AppColors.textMuted),
          if (icon != null) const SizedBox(width: 10),
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try { final dt = DateTime.parse(iso); return '${dt.day}.${dt.month}.${dt.year}'; }
    catch (_) { return ''; }
  }
}