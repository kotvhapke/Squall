import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static const String fontFamily = 'Inter';

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        secondary: AppColors.electricBlue,
        surface: AppColors.darkBlue,
        error: AppColors.danger,
      ),
      dividerColor: AppColors.border,
      cardColor: AppColors.darkBlue,
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.darkBlue),
      inputDecorationTheme: _inputDecorationTheme,
      textTheme: _textTheme,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.darkBlue,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static const _textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5),
    displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3),
    headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
    titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
    bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.4),
    bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
    bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textMuted),
    labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: 0.3),
    labelMedium: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3),
    labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.2),
  );

  static final _inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.inputBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.electricBlue.withValues(alpha: 0.6), width: 1),
    ),
    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
  );

  static BoxDecoration panelDecoration({
    double radius = 12,
    Color? borderColor,
    double borderWidth = 1,
  }) {
    return BoxDecoration(
      color: AppColors.panelBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? AppColors.border,
        width: borderWidth,
      ),
    );
  }

  static BoxDecoration panelWithGlow({
    double radius = 12,
    Color glowColor = AppColors.glowBlue,
    double glowRadius = 30,
  }) {
    return BoxDecoration(
      color: AppColors.panelBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border, width: 1),
      boxShadow: [
        BoxShadow(
          color: glowColor,
          blurRadius: glowRadius,
          spreadRadius: -glowRadius / 2,
        ),
      ],
    );
  }

  static BoxDecoration selectedItemDecoration() {
    return BoxDecoration(
      color: AppColors.panelBgOpaque,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderActive, width: 1),
      boxShadow: [
        BoxShadow(
          color: AppColors.glowBlue,
          blurRadius: 12,
          spreadRadius: -8,
        ),
      ],
    );
  }

  static BoxDecoration avatarDecoration(double size) {
    return BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.border, width: 1),
      boxShadow: [
        BoxShadow(
          color: AppColors.glowBlue,
          blurRadius: 8,
          spreadRadius: -4,
        ),
      ],
    );
  }

  static BoxDecoration speakingRing() {
    return BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.coldNeon, width: 2),
      boxShadow: [
        BoxShadow(
          color: AppColors.coldNeon.withValues(alpha: 0.3),
          blurRadius: 16,
          spreadRadius: -6,
        ),
      ],
    );
  }

  static EdgeInsets get panelPadding => const EdgeInsets.all(12);
  static EdgeInsets get compactPanelPadding => const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
  static BorderRadius get borderRadius => BorderRadius.circular(12);
  static BorderRadius get smallRadius => BorderRadius.circular(10);
  static Duration get animationDuration => const Duration(milliseconds: 180);
}