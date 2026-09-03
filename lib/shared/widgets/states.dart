import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.panelBgOpaque,
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Icon(icon, size: 32, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
          )),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(
                fontSize: 13, color: AppColors.textMuted,
              )),
            ),
          ],
        ],
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.electricBlue,
        strokeWidth: 2,
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.warning_rounded,
        title: 'Something went wrong',
        subtitle: message,
      ),
    );
  }
}