import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';

class AnimatedUnreadDot extends StatefulWidget {
  final double size;
  final Color color;

  const AnimatedUnreadDot({
    super.key,
    this.size = 8,
    this.color = AppColors.electricBlue,
  });

  @override
  State<AnimatedUnreadDot> createState() => _AnimatedUnreadDotState();
}

class _AnimatedUnreadDotState extends State<AnimatedUnreadDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Transform.scale(
          scale: _pulse.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double liftAmount;

  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.liftAmount = 2.0,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: _hovered
            ? (widget.onTap != null
                ? Matrix4.translationValues(0, -widget.liftAmount, 0)
                : Matrix4.identity())
            : Matrix4.identity(),
        decoration: BoxDecoration(
          border: _hovered && widget.onTap != null
              ? Border.all(color: AppColors.electricBlue.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: widget.onTap != null
            ? InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: widget.child,
              )
            : widget.child,
      ),
    );
  }
}

class ShimmerWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _shimmer = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: const [
                AppColors.shimmerBase,
                AppColors.shimmerHighlight,
                AppColors.shimmerBase,
              ],
              stops: [
                (_shimmer.value - 0.5).clamp(0.0, 1.0),
                _shimmer.value.clamp(0.0, 1.0),
                (_shimmer.value + 0.5).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}