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
  late final Animation<double> _tapPulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _tapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _breath = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
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
    Widget logo = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer neon glow
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.electricBlue.withValues(alpha: 0.25 * glow),
                  blurRadius: widget.size * 0.25,
                  spreadRadius: widget.size * 0.05,
                ),
              ],
            ),
          ),
          // White bold S with neon-blue drop shadow
          Text(
            'S',
            style: TextStyle(
              fontSize: widget.size * 0.8,
              height: 1.0,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: AppColors.electricBlue.withValues(alpha: 0.8 + 0.2 * glow),
                  blurRadius: widget.size * 0.14,
                ),
                Shadow(
                  color: AppColors.coldNeon.withValues(alpha: 0.6),
                  blurRadius: widget.size * 0.30,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (widget.tappable) {
      logo = GestureDetector(onTap: _onTap, child: logo);
    }
    return logo;
  }
}