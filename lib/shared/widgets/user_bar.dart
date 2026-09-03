import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';
import 'package:squall/test_data/models.dart';

class UserBar extends StatelessWidget {
  final SquallUser currentUser;
  final VoidCallback? onSettings;

  const UserBar({
    super.key,
    required this.currentUser,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panelBg,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          SquallAvatar(name: currentUser.name, size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(currentUser.name, style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                )),
                Text(currentUser.status.name, style: const TextStyle(
                  fontSize: 10, color: AppColors.textMuted,
                )),
              ],
            ),
          ),
          _icon(Icons.mic),
          const SizedBox(width: 6),
          _icon(Icons.headphones),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onSettings,
            child: _icon(Icons.settings, active: false),
          ),
        ],
      ),
    );
  }

  Widget _icon(IconData icon, {bool active = true}) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: active ? Colors.transparent : AppColors.panelBgOpaque,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: active ? AppColors.textSecondary : AppColors.textMuted),
    );
  }
}