import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';

class SquallPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool withGlow;
  final EdgeInsetsGeometry? margin;

  const SquallPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = 12,
    this.withGlow = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.panelBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: withGlow
            ? [BoxShadow(color: AppColors.glowBlue, blurRadius: 20, spreadRadius: -10)]
            : null,
      ),
      child: child,
    );
  }
}