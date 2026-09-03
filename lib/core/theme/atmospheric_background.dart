import 'dart:math';
import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';

class AtmosphericBackground extends StatefulWidget {
  final Widget child;
  final bool reducedEffects;

  const AtmosphericBackground({
    super.key,
    required this.child,
    this.reducedEffects = false,
  });

  @override
  State<AtmosphericBackground> createState() => _AtmosphericBackgroundState();
}

class _AtmosphericBackgroundState extends State<AtmosphericBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fogController;
  final List<_FogParticle> _particles = [];
  final List<_ElectricArc> _arcs = [];

  @override
  void initState() {
    super.initState();
    _fogController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _initParticles();
    _initArcs();
  }

  void _initArcs() {
    final rng = Random(42);
    for (int i = 0; i < 3; i++) {
      _arcs.add(_ElectricArc(
        startX: rng.nextDouble(),
        startY: rng.nextDouble(),
        endX: rng.nextDouble(),
        endY: rng.nextDouble(),
        opacity: 0.06 + rng.nextDouble() * 0.04,
        phase: rng.nextDouble() * 2 * pi,
        speed: 0.3 + rng.nextDouble() * 0.4,
      ));
    }
  }

  void _initParticles() {
    final rng = Random(42);
    for (int i = 0; i < 6; i++) {
      _particles.add(_FogParticle(
        x: rng.nextDouble(),
        y: 0.1 + rng.nextDouble() * 0.8,
        radius: 80 + rng.nextDouble() * 120,
        opacity: 0.04 + rng.nextDouble() * 0.04,
        driftX: (rng.nextDouble() - 0.5) * 0.003,
        driftY: (rng.nextDouble() - 0.5) * 0.001,
      ));
    }
  }

  @override
  void dispose() {
    _fogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reducedEffects) return widget.child;

    return AnimatedBuilder(
      animation: _fogController,
      builder: (context, child) {
        return Stack(
          children: [
            widget.child,
            IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _FogPainter(
                  particles: _particles,
                  arcs: _arcs,
                  time: _fogController.value,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FogParticle {
  final double x, y, radius, opacity, driftX, driftY;
  _FogParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.driftX,
    required this.driftY,
  });
}

class _ElectricArc {
  final double startX, startY, endX, endY, opacity, phase, speed;
  _ElectricArc({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.opacity,
    required this.phase,
    required this.speed,
  });
}

class _FogPainter extends CustomPainter {
  final List<_FogParticle> particles;
  final List<_ElectricArc> arcs;
  final double time;

  _FogPainter({
    required this.particles,
    required this.arcs,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dx = p.x + sin(time * 2 * pi + p.x * 10) * p.driftX * 100;
      final dy = p.y + cos(time * 2 * pi + p.y * 10) * p.driftY * 100;
      final paint = Paint()
        ..color = AppColors.electricBlue.withValues(alpha: p.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        p.radius,
        paint,
      );
    }

    for (final a in arcs) {
      final flicker = sin(time * 2 * pi * a.speed + a.phase);
      final alpha = a.opacity * (0.5 + 0.5 * flicker).clamp(0.0, 1.0);
      if (alpha < 0.01) continue;
      final paint = Paint()
        ..color = AppColors.electricBlue.withValues(alpha: alpha)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(a.startX * size.width, a.startY * size.height),
        Offset(a.endX * size.width, a.endY * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FogPainter old) => time != old.time;
}