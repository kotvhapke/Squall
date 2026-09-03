import 'dart:math';
import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';

class SpeakingIndicator extends StatefulWidget {
  final Widget child;
  final double size;
  final bool isSpeaking;

  const SpeakingIndicator({
    super.key,
    required this.child,
    this.size = 48,
    this.isSpeaking = false,
  });

  @override
  State<SpeakingIndicator> createState() => _SpeakingIndicatorState();
}

class _SpeakingIndicatorState extends State<SpeakingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.isSpeaking) _controller.repeat();
  }

  @override
  void didUpdateWidget(SpeakingIndicator old) {
    super.didUpdateWidget(old);
    if (widget.isSpeaking && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isSpeaking && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outerSize = widget.size + 12;
    final padding = (outerSize - widget.size) / 2;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: outerSize,
          height: outerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isSpeaking
                  ? AppColors.coldNeon.withValues(alpha: 0.4 + 0.6 * (0.5 + 0.5 * sin(_controller.value * 2 * pi)))
                  : AppColors.border,
              width: widget.isSpeaking ? 2.0 : 1.0,
            ),
            boxShadow: widget.isSpeaking
                ? [
                    BoxShadow(
                      color: AppColors.electricBlue.withValues(alpha: 0.15 + 0.1 * sin(_controller.value * 2 * pi)),
                      blurRadius: 8 + 4 * sin(_controller.value * 2 * pi),
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}