import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/shared/widgets/speaking_indicator.dart';

class SquallAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String status;
  final double size;
  final bool isSpeaking;

  const SquallAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.status = 'online',
    this.size = 40,
    this.isSpeaking = false,
  });

  Color _statusColor() {
    if (status == 'online') return AppColors.voiceActive;
    if (status == 'idle') return AppColors.warning;
    if (status == 'dnd') return AppColors.danger;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final initials = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();

    final avatarCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.serverIconBg,
        image: (avatarUrl != null && avatarUrl!.isNotEmpty)
            ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: (avatarUrl != null && avatarUrl!.isNotEmpty)
          ? null
          : Text(initials,
              style: TextStyle(
                fontSize: size * 0.35,
                fontWeight: FontWeight.w700,
                color: AppColors.electricBlue,
              )),
    );

    final avatarWithSpeaking = SpeakingIndicator(
      size: size,
      isSpeaking: isSpeaking,
      child: avatarCircle,
    );

    // Status dot placed outside speaking indicator
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarWithSpeaking,
        if (status != 'offline')
          Positioned(
            bottom: -1,
            right: -1,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _statusColor(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}