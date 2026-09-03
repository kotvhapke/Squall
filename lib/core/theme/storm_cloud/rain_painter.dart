import 'dart:math';
import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';

class RainDrop {
  double x, y, speed, length, opacity;
  RainDrop(this.x, this.y, this.speed, this.length, this.opacity);
}

class RainPainter extends CustomPainter {
  final List<RainDrop> drops;
  final double time;
  final double cloudBottom;

  RainPainter({required this.drops, required this.time, this.cloudBottom = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final d in drops) {
      final y = (d.y + time * d.speed) % (size.height - cloudBottom);
      final dy = cloudBottom + y;
      if (dy > size.height) continue;
      paint.color = AppColors.electricBlue.withValues(alpha: d.opacity * 0.3);
      canvas.drawLine(
        Offset(d.x, dy),
        Offset(d.x, dy + d.length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

List<RainDrop> generateRainDrops(int count, Size size, double cloudBottom, [Random? rng]) {
  final r = rng ?? Random(42);
  return List.generate(count, (_) {
    return RainDrop(
      r.nextDouble() * size.width,
      r.nextDouble() * (size.height - cloudBottom),
      60 + r.nextDouble() * 100,
      10 + r.nextDouble() * 8,
      0.2 + r.nextDouble() * 0.25,
    );
  });
}