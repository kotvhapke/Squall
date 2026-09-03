import 'package:flutter/material.dart';

class StormCloudShape {
  final Rect bounds;

  StormCloudShape(this.bounds);

  static Path _buildNormalizedPath() {
    final p = Path();
    // Start bottom-left
    p.moveTo(120, 310);
    // Irregular bottom — 4 uneven dips
    // Dip 1 (left)
    p.cubicTo(100, 330, 140, 340, 165, 322);
    // Dip 2 (center-left) — deepest
    p.cubicTo(190, 360, 260, 368, 280, 338);
    // Dip 3 (center-right)
    p.cubicTo(310, 350, 370, 356, 405, 330);
    // Dip 4 (right) — shallow
    p.cubicTo(440, 340, 500, 344, 520, 326);
    // Right side transition
    p.cubicTo(560, 336, 620, 332, 658, 334);
    // Right dome
    p.cubicTo(710, 334, 754, 310, 750, 266);
    p.cubicTo(746, 216, 708, 176, 652, 178);
    // Upper right
    p.cubicTo(618, 126, 548, 118, 500, 148);
    p.cubicTo(505, 108, 486, 68, 447, 43);
    // Central dome
    p.cubicTo(395, 8, 325, 20, 290, 66);
    p.cubicTo(230, 58, 178, 92, 155, 148);
    // Upper left
    p.cubicTo(105, 140, 60, 170, 48, 220);
    p.cubicTo(35, 270, 65, 310, 120, 310);
    p.close();
    return p;
  }

  Path buildPath() {
    final ref = Rect.fromLTWH(0, 0, 800, 420);
    final scaleX = bounds.width / ref.width;
    final scaleY = bounds.height / ref.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final offsetX = bounds.center.dx - ref.center.dx * scale;
    final offsetY = bounds.center.dy - ref.center.dy * scale;
    final matrix = Matrix4.identity()
      ..translate(offsetX, offsetY)
      ..scale(scale, scale);
    return _buildNormalizedPath().transform(matrix.storage);
  }

  void paint(Canvas canvas, double glowPhase) {
    final path = buildPath();

    // Very faint outer glow
    final glowPaint = Paint()
      ..color = const Color(0xFF2F80FF).withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawPath(path, glowPaint);

    // Main dark silhouette
    canvas.drawPath(path, Paint()..color = const Color(0xFF0F1729));

    // Shading clipped to path
    canvas.save();
    canvas.clipPath(path);

    // Top-left cold light
    final topLight = Paint()
      ..color = const Color(0xFF1E3050).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    canvas.drawOval(Rect.fromCenter(
      center: Offset(bounds.left + bounds.width * 0.25, bounds.top + bounds.height * 0.25),
      width: bounds.width * 0.35,
      height: bounds.height * 0.35,
    ), topLight);

    // Deep shadow along bottom
    final bottomShadow = Paint()
      ..color = const Color(0xFF040810).withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(Rect.fromCenter(
      center: Offset(bounds.center.dx, bounds.bottom - bounds.height * 0.10),
      width: bounds.width * 0.75,
      height: bounds.height * 0.25,
    ), bottomShadow);

    // Left shadow mass
    final leftShadow = Paint()
      ..color = const Color(0xFF080E1A).withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawOval(Rect.fromCenter(
      center: Offset(bounds.left + bounds.width * 0.15, bounds.center.dy),
      width: bounds.width * 0.20,
      height: bounds.height * 0.40,
    ), leftShadow);

    // Right shadow mass
    final rightShadow = Paint()
      ..color = const Color(0xFF080E1A).withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawOval(Rect.fromCenter(
      center: Offset(bounds.right - bounds.width * 0.15, bounds.center.dy),
      width: bounds.width * 0.20,
      height: bounds.height * 0.40,
    ), rightShadow);

    canvas.restore();
  }
}