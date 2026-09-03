import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';

class SquallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool fullWidth;
  final double height;

  const SquallButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.primary = true,
    this.fullWidth = true,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final bg = primary ? AppColors.blue : Colors.transparent;
    final BoxBorder? border = primary ? null : Border.all(color: AppColors.border, width: 1);
    final textColor = primary ? AppColors.textPrimary : AppColors.electricBlue;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isEnabled ? bg : bg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: border,
          boxShadow: isEnabled && primary
              ? [BoxShadow(color: AppColors.blue.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: -4)]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: textColor.withValues(alpha: isEnabled ? 1 : 0.5)),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: isEnabled ? 1 : 0.5),
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}