import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart';

void main() {
  final sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256];
  final pngs = <int, Uint8List>{};

  for (final s in sizes) {
    final img = generateIcon(s);
    pngs[s] = Uint8List.fromList(encodePng(img));
  }

  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(encodeIco(pngs));
  File('assets/branding/squall-icon-256.png').writeAsBytesSync(pngs[256]!);
  File('assets/branding/squall-icon-user.png').writeAsBytesSync(pngs[256]!);
  print('OK: ${sizes.length} sizes');
}

Image generateIcon(int size) {
  final img = Image(width: size, height: size);
  final s = size;
  final half = s / 2;
  final rr = s * 0.22;
  final x0 = s * 0.28;
  final y0 = s * 0.22;
  final w = s * 0.44;
  final h = s * 0.56;

  // Colors
  final bgColor = ColorRgb8(5, 7, 12);
  final cyan = ColorRgb8(0, 168, 255);
  final brightCyan = ColorRgb8(120, 235, 255);

  for (int y = 0; y < s; y++) {
    for (int x = 0; x < s; x++) {
      // Rounded square background
      bool inside = true;
      if (x < rr && y < rr) inside = (x - rr) * (x - rr) + (y - rr) * (y - rr) <= rr * rr;
      else if (x >= s - rr && y < rr) inside = (x - (s - 1 - rr)) * (x - (s - 1 - rr)) + (y - rr) * (y - rr) <= rr * rr;
      else if (x < rr && y >= s - rr) inside = (x - rr) * (x - rr) + (y - (s - 1 - rr)) * (y - (s - 1 - rr)) <= rr * rr;
      else if (x >= s - rr && y >= s - rr) inside = (x - (s - 1 - rr)) * (x - (s - 1 - rr)) + (y - (s - 1 - rr)) * (y - (s - 1 - rr)) <= rr * rr;

      if (!inside) {
        img.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }

      img.setPixelRgba(x, y, bgColor.r, bgColor.g, bgColor.b, 255);

      // Draw neon S shape: thick path with glow
      // Check distance to the S path
      // S path: top-right, middle-left, bottom-right
      final pts = [
        Point(x0, y0 + h * 0.12),
        Point(x0 + w, y0),
        Point(x0 + w, y0 + h * 0.45),
        Point(x0, y0 + h * 0.5),
        Point(x0, y0 + h * 0.88),
        Point(x0 + w, y0 + h),
      ];

      double minDist = double.infinity;
      for (int i = 0; i < pts.length - 1; i++) {
        final d = distToSegment(x, y, pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y);
        if (d < minDist) minDist = d;
      }

      final glowWidth = s * 0.12;
      final strokeWidth = s * 0.045;

      if (minDist < strokeWidth) {
        // Bright cyan core
        img.setPixelRgba(x, y, brightCyan.r, brightCyan.g, brightCyan.b, 255);
      } else if (minDist < glowWidth) {
        // Neon glow
        final alpha = ((1 - (minDist - strokeWidth) / (glowWidth - strokeWidth)) * 200).round().clamp(0, 200);
        img.setPixelRgba(x, y, cyan.r, cyan.g, cyan.b, (255 * alpha / 255).round());
      }
    }
  }
  return img;
}

double distToSegment(int px, int py, double x1, double y1, double x2, double y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final lenSq = dx * dx + dy * dy;
  if (lenSq == 0) return sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1));
  double t = ((px - x1) * dx + (py - y1) * dy) / lenSq;
  t = t.clamp(0.0, 1.0);
  final projX = x1 + t * dx;
  final projY = y1 + t * dy;
  return sqrt((px - projX) * (px - projX) + (py - projY) * (py - projY));
}

class Point {
  final double x, y;
  Point(this.x, this.y);
}

Uint8List encodeIco(Map<int, Uint8List> pngs) {
  final out = BytesBuilder();
  out.addUint16(0); out.addUint16(1); out.addUint16(pngs.length);
  final dir = BytesBuilder();
  final data = BytesBuilder();
  int offset = 6 + pngs.length * 16;
  for (final e in pngs.entries) {
    final s = e.key;
    dir.addByte(s == 256 ? 0 : s); dir.addByte(s == 256 ? 0 : s);
    dir.addByte(0); dir.addByte(0);
    dir.addUint16(1); dir.addUint16(32);
    dir.addUint32(e.value.length);
    dir.addUint32(offset);
    data.add(e.value);
    offset += e.value.length;
  }
  final result = BytesBuilder();
  result.add(out.toBytes()); result.add(dir.toBytes()); result.add(data.toBytes());
  return result.toBytes();
}

extension _BB on BytesBuilder {
  void addByte(int v) => add([v & 0xFF]);
  void addUint16(int v) { addByte(v); addByte(v >> 8); }
  void addUint32(int v) { addByte(v); addByte(v >> 8); addByte(v >> 16); addByte(v >> 24); }
}