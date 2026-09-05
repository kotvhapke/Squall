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
  final rr = s * 0.22; // corner radius

  // Use a bold S drawn with thick rounded strokes
  // We draw 3 rounded rectangles forming an S
  final thick = s * 0.22;
  final r = thick / 2;
  final pad = s * 0.14;

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

      // Dark background
      img.setPixelRgba(x, y, 5, 7, 12, 255);

      // Draw the S as three bars + connecting verticals
      final barH = thick;
      final barR = r;

      // Top bar: right side, from center to right edge
      if (_insideBar(x, y, half - barH * 0.4, pad, s * 0.65, pad + barH, barR)) {
        img.setPixelRgba(x, y, 255, 255, 255, 255); continue;
      }

      // Middle bar: left side, bridge
      if (_insideBar(x, y, s * 0.12, half - barH / 2, s * 0.55, half + barH / 2, barR)) {
        img.setPixelRgba(x, y, 255, 255, 255, 255); continue;
      }

      // Bottom bar: left side, from left edge to center
      if (_insideBar(x, y, s * 0.12, s - pad - barH, half + barH * 0.4, s - pad, barR)) {
        img.setPixelRgba(x, y, 255, 255, 255, 255); continue;
      }

      // Right vertical connector: between top and middle
      if (x > s * 0.52 && x < s * 0.52 + barH && y > pad + barH && y < half + barH / 2) {
        img.setPixelRgba(x, y, 255, 255, 255, 255); continue;
      }

      // Left vertical connector: between middle and bottom
      if (x > s * 0.12 && x < s * 0.12 + barH && y > half - barH / 2 && y < s - pad) {
        img.setPixelRgba(x, y, 255, 255, 255, 255); continue;
      }
    }
  }
  return img;
}

bool _insideBar(int px, int py, double x1, double y1, double x2, double y2, double r) {
  if (px < x1 - r || px > x2 + r || py < y1 - r || py > y2 + r) return false;
  if (px < x1 + r && py < y1 + r) return (px - (x1 + r)) * (px - (x1 + r)) + (py - (y1 + r)) * (py - (y1 + r)) <= r * r;
  if (px > x2 - r && py < y1 + r) return (px - (x2 - r)) * (px - (x2 - r)) + (py - (y1 + r)) * (py - (y1 + r)) <= r * r;
  if (px < x1 + r && py > y2 - r) return (px - (x1 + r)) * (px - (x1 + r)) + (py - (y2 - r)) * (py - (y2 - r)) <= r * r;
  if (px > x2 - r && py > y2 - r) return (px - (x2 - r)) * (px - (x2 - r)) + (py - (y2 - r)) * (py - (y2 - r)) <= r * r;
  return true;
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