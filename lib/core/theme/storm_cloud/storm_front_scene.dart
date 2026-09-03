import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;

// ────────────────────────────────────
// Storm front — 5 cloud masses, rain, glass panel
// ────────────────────────────────────

class StormFrontScene extends StatefulWidget {
  final Animation<double> animation;
  final Widget? child;

  const StormFrontScene({super.key, required this.animation, this.child});

  @override
  State<StormFrontScene> createState() => _StormFrontSceneState();
}

class _StormFrontSceneState extends State<StormFrontScene> {
  List<_RainLayer>? _rainLayers;
  final _rng = Random(42);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final time = widget.animation.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            _rainLayers ??= _createRainLayers(size.width);
            final frontH = size.height * 0.40;

            return Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: _FrontPainter(
                    size: size,
                    time: time,
                    flashTime: 0,
                    rainLayers: _rainLayers!,
                  ),
                ),
                Positioned(
                  left: 12, right: 12,
                  top: frontH + 20,
                  bottom: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1729).withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2F80FF).withValues(alpha: 0.15)),
                        ),
                        child: widget.child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<_RainLayer> _createRainLayers(double width) {
    return [
      _RainLayer(particles: _genParticles(40, width), speed: 0.12, opacity: 0.10, length: 6),
      _RainLayer(particles: _genParticles(35, width), speed: 0.25, opacity: 0.18, length: 10),
      _RainLayer(particles: _genParticles(20, width), speed: 0.40, opacity: 0.25, length: 15),
    ];
  }

  List<_RainParticle> _genParticles(int count, double width) {
    return List.generate(count, (_) => _RainParticle(
      _rng.nextDouble() * width,
      _rng.nextDouble(),
      _rng.nextDouble() * 4,
    ));
  }
}

class _RainParticle {
  final double x, startY, drift;
  _RainParticle(this.x, this.startY, this.drift);
}

class _RainLayer {
  final List<_RainParticle> particles;
  final double speed, opacity, length;
  _RainLayer({required this.particles, required this.speed, required this.opacity, required this.length});
}

// ────────────────────────────────────
// Cloud shape
// ────────────────────────────────────

class _CloudData {
  final double xPos, yPos, scale, importance;
  _CloudData(this.xPos, this.yPos, this.scale, this.importance);
}

class StormFrontPainter {
  static void paint(Canvas canvas, Size size, double time, double flashTime) {
    final frontH = size.height * 0.40;
    final baseY = size.height * 0.02;
    final flash = max(0.0, 1.0 - (time - flashTime).abs() * 3).clamp(0.0, 1.0);

    final clouds = [
      _CloudData(-0.10, 0.30, 0.55, 0.8),
      _CloudData(0.15, 0.48, 0.70, 0.6),
      _CloudData(0.48, 0.38, 0.80, 1.0),
      _CloudData(0.75, 0.45, 0.65, 0.7),
      _CloudData(1.05, 0.35, 0.55, 0.5),
    ];

    for (final c in clouds) {
      final cx = c.xPos * size.width + sin(time * (0.3 + c.importance * 0.2) + c.xPos) * c.importance * 6;
      final cy = baseY + c.yPos * frontH + sin(time * (0.2 + c.importance * 0.15) + c.xPos * 2) * (2 + c.importance * 3);
      final w = c.scale * size.width * 0.38;
      final h = c.scale * frontH * 0.55;
      _paintCloud(canvas, cx, cy, w, h, flash * c.importance);
    }
  }

  static void _paintCloud(Canvas canvas, double cx, double cy, double w, double h, double flash) {
    final path = _buildPath(cx, cy, w, h);

    final glow = Paint()
      ..color = const Color(0xFF2F80FF).withValues(alpha: 0.04 + 0.02 * flash)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, Paint()..color = const Color(0xFF0F1729));

    canvas.save();
    canvas.clipPath(path);

    final topLight = Paint()
      ..color = const Color(0xFF1E3050).withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - w * 0.05, cy - h * 0.10), width: w * 0.40, height: h * 0.30), topLight);

    final botShadow = Paint()
      ..color = const Color(0xFF040810).withValues(alpha: 0.50)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + h * 0.10), width: w * 0.70, height: h * 0.25), botShadow);

    canvas.restore();
  }

  static Path _buildPath(double cx, double cy, double w, double h) {
    final p = Path();
    final left = cx - w / 2;
    final right = cx + w / 2;
    final top = cy - h / 2;
    final bot = cy + h / 2;

    p.moveTo(left + w * 0.05, bot);
    p.cubicTo(left + w * 0.12, bot + h * 0.12, left + w * 0.22, bot + h * 0.18, left + w * 0.28, bot + h * 0.04);
    p.cubicTo(left + w * 0.35, bot + h * 0.15, left + w * 0.48, bot + h * 0.22, left + w * 0.52, bot + h * 0.06);
    p.cubicTo(left + w * 0.58, bot + h * 0.16, left + w * 0.68, bot + h * 0.20, left + w * 0.74, bot + h * 0.04);
    p.cubicTo(left + w * 0.80, bot + h * 0.12, left + w * 0.90, bot + h * 0.14, right - w * 0.05, bot);
    p.cubicTo(right + w * 0.02, bot - h * 0.15, right + w * 0.01, top + h * 0.65, right - w * 0.08, top + h * 0.40);
    p.cubicTo(right - w * 0.10, top + h * 0.12, right - w * 0.20, top + h * 0.05, right - w * 0.30, top + h * 0.08);
    p.cubicTo(right - w * 0.35, top - h * 0.04, left + w * 0.35, top - h * 0.04, left + w * 0.30, top + h * 0.08);
    p.cubicTo(left + w * 0.20, top + h * 0.05, left + w * 0.10, top + h * 0.12, left + w * 0.08, top + h * 0.40);
    p.cubicTo(left - w * 0.01, top + h * 0.65, left - w * 0.02, bot - h * 0.15, left + w * 0.05, bot);
    p.close();
    return p;
  }

  static double getBottomY(double x, Size size, double time) {
    return size.height * 0.30 + sin(time * 0.3 + x * 0.01) * 8;
  }
}

// ────────────────────────────────────
// Painter
// ────────────────────────────────────

class _FrontPainter extends CustomPainter {
  final Size size;
  final double time, flashTime;
  final List<_RainLayer> rainLayers;

  _FrontPainter({
    required this.size,
    required this.time,
    required this.flashTime,
    required this.rainLayers,
  }) : super(repaint: null);

  @override
  void paint(Canvas canvas, Size _) {
    // Fog
    final fog = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2F80FF).withValues(alpha: 0.04),
          const Color(0xFF2F80FF).withValues(alpha: 0.01),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, size.height * 0.25, size.width, size.height * 0.30));
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.25, size.width, size.height * 0.30), fog);

    // Clouds
    StormFrontPainter.paint(canvas, size, time, flashTime);

    // Rain
    for (final layer in rainLayers) {
      final paint = Paint()
        ..strokeWidth = 0.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (final p in layer.particles) {
        final y = (p.startY + time * layer.speed) % 1.0;
        final dy = size.height * 0.35 + y * size.height * 0.65;
        if (dy >= size.height) continue;
        paint.color = const Color(0xFF2F80FF).withValues(alpha: layer.opacity * (1.0 - y * 0.3));
        canvas.drawLine(
          Offset(p.x + p.drift * 0.2, dy),
          Offset(p.x + p.drift, dy + layer.length),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FrontPainter old) => true;
}