import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';

class SquallBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;

  const SquallBackButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Back',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textSecondary),
      ),
    );
  }
}