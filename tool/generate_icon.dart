import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final dir = Directory('windows/runner/resources');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final brandingDir = Directory('assets/branding');
  if (!brandingDir.existsSync()) brandingDir.createSync(recursive: true);

  final sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256];
  final pngs = <int, Uint8List>{};

  for (final s in sizes) {
    pngs[s] = generatePng(s);
  }

  final ico = encodeIco(pngs);
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(ico);
  File('assets/branding/squall-icon-256.png').writeAsBytesSync(pngs[256]!);
  File('assets/branding/squall-icon-user.png').writeAsBytesSync(pngs[256]!);
  print('OK: ${ico.length} bytes, ${sizes.length} sizes');
}

Uint8List generatePng(int size) {
  final s = size;
  final pixels = Uint8List(s * s * 4);
  final cx = s / 2, cy = s / 2;
  final pad = s * 0.17; // left/right padding
  final topPad = s * 0.17;
  final botPad = s * 0.17;
  final thick = s * 0.22; // bar thickness
  final r = s * 0.06; // corner radius

  for (int y = 0; y < s; y++) {
    for (int x = 0; x < s; x++) {
      final i = (y * s + x) * 4;

      // Dark background (slightly rounded square)
      pixels[i] = 5; pixels[i+1] = 7; pixels[i+2] = 12; pixels[i+3] = 255;

      // Check if pixel is inside the white S
      // S consists of 3 rounded horizontal bars:
      // Top bar: top-right going left
      // Middle bar: bridge from right to left
      // Bottom bar: bottom-left going right

      bool inside = false;

      // Top bar: top area, from center to right edge
      if (_insideBar(x, y, cx, topPad, cx + s/2 - pad, topPad + thick, r)) inside = true;

      // Middle bar: middle area, from left to right (bridge, shifted left)
      if (_insideBar(x, y, pad, cy - thick/2, cx + s/2 - pad, cy + thick/2, r)) inside = true;

      // Bottom bar: bottom area, from left to center
      if (_insideBar(x, y, pad, s - botPad - thick, cx, s - botPad, r)) inside = true;

      // Vertical connector: mid-left area connecting middle and bottom bars
      if (x > pad && x < pad + thick && y > cy - thick/2 && y < s - botPad) inside = true;

      // Small vertical stub on top-right connecting top and middle bars
      if (x > cx + s/2 - pad - thick && x < cx + s/2 - pad && y > topPad + thick && y < cy + thick/2) inside = true;

      if (inside) {
        // White letter with slight anti-alias on edges
        int alpha = 255;
        // Simple edge detection for anti-alias
        if (x > 0 && x < s-1 && y > 0 && y < s-1) {
          int count = 0;
          for (int dx = -1; dx <= 1; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
              if (dx == 0 && dy == 0) continue;
              final ni = ((y + dy) * s + (x + dx)) * 4;
              if (pixels[ni + 3] == 0 || pixels[ni] == 5) count++;
            }
          }
          if (count > 5) alpha = 180;
          if (count > 7) alpha = 80;
        }
        setPx(pixels, s, x, y, 255, 255, 255, alpha);
      }
    }
  }
  return pngEncode(pixels, s, s);
}

bool _insideBar(int px, int py, double x1, double y1, double x2, double y2, double r) {
  if (px < x1 - r || px > x2 + r || py < y1 - r || py > y2 + r) return false;
  // Check corners
  if (px < x1 + r && py < y1 + r) return (px - (x1 + r)) * (px - (x1 + r)) + (py - (y1 + r)) * (py - (y1 + r)) <= r * r;
  if (px > x2 - r && py < y1 + r) return (px - (x2 - r)) * (px - (x2 - r)) + (py - (y1 + r)) * (py - (y1 + r)) <= r * r;
  if (px < x1 + r && py > y2 - r) return (px - (x1 + r)) * (px - (x1 + r)) + (py - (y2 - r)) * (py - (y2 - r)) <= r * r;
  if (px > x2 - r && py > y2 - r) return (px - (x2 - r)) * (px - (x2 - r)) + (py - (y2 - r)) * (py - (y2 - r)) <= r * r;
  return true;
}

void setPx(Uint8List p, int s, int x, int y, int r, int g, int b, int a) {
  final i = (y * s + x) * 4;
  final alpha = a / 255.0;
  p[i] = (p[i] * (1 - alpha) + r * alpha).round().clamp(0, 255);
  p[i+1] = (p[i+1] * (1 - alpha) + g * alpha).round().clamp(0, 255);
  p[i+2] = (p[i+2] * (1 - alpha) + b * alpha).round().clamp(0, 255);
  p[i+3] = 255;
}

// ---------- PNG encoder ----------
Uint8List pngEncode(Uint8List pixels, int w, int h) {
  final out = BytesBuilder();
  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  out.add(makeChunk('IHDR', makeIHDR(w, h)));
  final raw = BytesBuilder();
  for (int y = 0; y < h; y++) {
    raw.addByte(0);
    for (int x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      raw.addByte(pixels[i]);
      raw.addByte(pixels[i+1]);
      raw.addByte(pixels[i+2]);
      raw.addByte(pixels[i+3]);
    }
  }
  out.add(makeChunk('IDAT', deflate(raw.toBytes())));
  out.add([0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82]);
  return out.toBytes();
}

Uint8List makeIHDR(int w, int h) {
  final b = BytesBuilder();
  b.addUint32(w); b.addUint32(h);
  b.addByte(8); b.addByte(6); b.addByte(0); b.addByte(0); b.addByte(0);
  return b.toBytes();
}

Uint8List makeChunk(String type, Uint8List data) {
  final b = BytesBuilder();
  b.addUint32(data.length);
  b.add(type.codeUnits);
  b.add(data);
  b.addUint32(crc32([...type.codeUnits, ...data]));
  return b.toBytes();
}

int crc32(List<int> data) {
  int crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      if (crc & 1 != 0) crc = (crc >> 1) ^ 0xEDB88320;
      else crc >>= 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

Uint8List deflate(Uint8List data) {
  final out = BytesBuilder();
  int pos = 0;
  while (pos < data.length) {
    final finalBlock = (pos + 65535 >= data.length) ? 1 : 0;
    final chunkLen = (data.length - pos).clamp(0, 65535);
    out.addByte(finalBlock);
    out.addByte(chunkLen & 0xFF); out.addByte((chunkLen >> 8) & 0xFF);
    out.addByte((~chunkLen) & 0xFF); out.addByte(((~chunkLen) >> 8) & 0xFF);
    out.add(data.sublist(pos, pos + chunkLen));
    pos += chunkLen;
  }
  return out.toBytes();
}

Uint8List encodeIco(Map<int, Uint8List> pngs) {
  final header = BytesBuilder();
  header.addUint16(0); header.addUint16(1); header.addUint16(pngs.length);
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
  result.add(header.toBytes());
  result.add(dir.toBytes());
  result.add(data.toBytes());
  return result.toBytes();
}

extension _BB on BytesBuilder {
  void addByte(int v) => add([v & 0xFF]);
  void addUint16(int v) { addByte(v & 0xFF); addByte((v >> 8) & 0xFF); }
  void addUint32(int v) { addByte(v & 0xFF); addByte((v >> 8) & 0xFF); addByte((v >> 16) & 0xFF); addByte((v >> 24) & 0xFF); }
}