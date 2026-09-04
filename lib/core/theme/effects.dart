import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';

class AppEffects {
  static Widget ambientGlow({required Color color, double width = 200, double height = 200, double blur = 80}) {
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: blur, spreadRadius: -blur / 3)],
      ),
    );
  }

  static Widget verticalDivider() {
    return Container(width: 1, height: 24, color: AppColors.border);
  }

  static Widget squallLogo({double size = 40}) {
    return _AnimatedLogo(size: size, reduced: false, tappable: false);
  }

  static Widget squallLogoReduced({double size = 40}) {
    return _AnimatedLogo(size: size, reduced: true, tappable: false);
  }

  static Widget squallLogoTappable({double size = 40, VoidCallback? onTap}) {
    return _AnimatedLogo(size: size, reduced: false, tappable: true, onTap: onTap);
  }
}

class _AnimatedLogo extends StatefulWidget {
  final double size;
  final bool reduced;
  final bool tappable;
  final VoidCallback? onTap;
  const _AnimatedLogo({required this.size, required this.reduced, this.tappable = false, this.onTap});

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _tapController;
  late final Animation<double> _breath;
  late final Animation<double> _flicker;
  late final Animation<double> _tapPulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _tapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _breath = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
    _flicker = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
    _tapPulse = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeOut));
    if (!widget.reduced) _controller.repeat(reverse: true);
  }

  void _onTap() {
    if (_tapController.isAnimating) return;
    _tapController.forward().then((_) => _tapController.reverse());
    widget.onTap?.call();
  }

  @override
  void dispose() { _controller.dispose(); _tapController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final glow = widget.reduced ? 0.0 : _breath.value + _tapPulse.value * 0.5;
    final flick = widget.reduced ? 0.5 : _flicker.value + _tapPulse.value * 0.3;
    Widget logo = CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _SquallSPainter(glowIntensity: glow.clamp(0.0, 1.5), flicker: flick.clamp(0.0, 1.0)),
    );
    if (widget.tappable) {
      logo = GestureDetector(onTap: _onTap, child: logo);
    }
    return logo;
  }
}

class _SquallSPainter extends CustomPainter {
  final double glowIntensity;
  final double flicker;

  _SquallSPainter({this.glowIntensity = 0.85, this.flicker = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final half = s / 2;
    final pad = s * 0.12;
    final w = s * 0.28;      // bar width
    final r = s * 0.08;      // corner radius

    // Soft ambient glow
    final ambient = Paint()
      ..color = AppColors.electricBlue.withValues(alpha: 0.10 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset(half, half), s * 0.42, ambient);

    // Glow paint
    final glowPaint = Paint()
      ..color = AppColors.electricBlue.withValues(alpha: 0.30 * glowIntensity)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Main fill paint
    final fillPaint = Paint()
      ..color = AppColors.coldNeon.withValues(alpha: 0.90 + 0.10 * flicker)
      ..style = PaintingStyle.fill;

    // Neon stroke paint
    final strokePaint = Paint()
      ..color = AppColors.coldNeon.withValues(alpha: 0.95 + 0.05 * flicker)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015
      ..strokeCap = StrokeCap.round;

    // Build the S shape: three rounded rectangles
    // Top bar (horizontal, top-right)
    final topBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(half - w * 0.3, pad, w * 1.3, w),
      Radius.circular(r),
    );
    // Middle bar (horizontal, connecting)
    final midBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(half - w * 0.3, half - w / 2, w * 0.9, w),
      Radius.circular(r),
    );
    // Bottom bar (horizontal, bottom-left)
    final botBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(half - w * 0.6, s - pad - w, w * 1.3, w),
      Radius.circular(r),
    );

    // Draw with glow
    for (final bar in [topBar, midBar, botBar]) {
      canvas.drawRRect(bar, glowPaint);
      canvas.drawRRect(bar, fillPaint);
      canvas.drawRRect(bar, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_SquallSPainter old) => old.glowIntensity != glowIntensity || old.flicker != flicker;
}