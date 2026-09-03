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
  print('OK: ${ico.length} bytes, ${sizes.length} sizes');
}

Uint8List generatePng(int size) {
  final s = size;
  final pixels = Uint8List(s * s * 4);
  for (int y = 0; y < s; y++) {
    for (int x = 0; x < s; x++) {
      final i = (y * s + x) * 4;
      final cx = s / 2, cy = s / 2;
      final cornerR = s * 0.08;
      bool inside = true;
      if (x < cornerR && y < cornerR) inside = (x - cornerR).abs() + (y - cornerR).abs() <= cornerR;
      else if (x >= s - cornerR && y < cornerR) inside = (x - (s - 1 - cornerR)).abs() + (y - cornerR).abs() <= cornerR;
      else if (x < cornerR && y >= s - cornerR) inside = (x - cornerR).abs() + (y - (s - 1 - cornerR)).abs() <= cornerR;
      else if (x >= s - cornerR && y >= s - cornerR) inside = (x - (s - 1 - cornerR)).abs() + (y - (s - 1 - cornerR)).abs() <= cornerR;

      if (!inside) { pixels[i] = 0; pixels[i+1] = 0; pixels[i+2] = 0; pixels[i+3] = 0; continue; }

      // Dark bg
      pixels[i] = 15; pixels[i+1] = 23; pixels[i+2] = 41; pixels[i+3] = 255;

      final r = s * 0.38;
      drawS(pixels, s, x, y, cx, cy, r);
      drawBolt(pixels, s, x, y, cx, cy, r);
      if (s > 24) drawRain(pixels, s, x, y, cx, cy, r);
    }
  }
  return pngEncode(pixels, s, s);
}

void drawS(Uint8List p, int s, int x, int y, double cx, double cy, double r) {
  final pts = [
    [cx - r, cy - r * 0.3], [cx - r * 0.1, cy - r * 0.7],
    [cx + r * 0.5, cy - r * 0.2], [cx + r * 0.2, cy + r * 0.1],
    [cx - r * 0.3, cy + r * 0.1], [cx - r * 0.5, cy + r * 0.4],
    [cx - r * 0.1, cy + r * 0.7], [cx + r * 0.5, cy + r * 0.4],
  ];
  final sw = (s / 7).round().clamp(1, 6);
  for (int i = 0; i < pts.length - 1; i++) {
    if (nearLine(x, y, pts[i][0], pts[i][1], pts[i+1][0], pts[i+1][1], sw)) {
      setPx(p, s, x, y, 0x56, 0xCC, 0xF2, 255); return;
    }
  }
}

void drawBolt(Uint8List p, int s, int x, int y, double cx, double cy, double r) {
  final pts = [
    [cx + r * 0.2, cy - r * 0.5], [cx - r * 0.1, cy - r * 0.05],
    [cx + r * 0.2, cy + r * 0.05], [cx - r * 0.15, cy + r * 0.4],
    [cx - r * 0.05, cy + r * 0.5],
  ];
  final sw = (s / 10).round().clamp(1, 4);
  for (int i = 0; i < pts.length - 1; i++) {
    if (nearLine(x, y, pts[i][0], pts[i][1], pts[i+1][0], pts[i+1][1], sw)) {
      setPx(p, s, x, y, 0xBB, 0x86, 0xFC, 255); return;
    }
  }
}

void drawRain(Uint8List p, int s, int x, int y, double cx, double cy, double r) {
  final rng = Random(42);
  for (int i = 0; i < 6; i++) {
    final rx = cx - r + rng.nextDouble() * r * 2;
    final ry = cy - r + rng.nextDouble() * r * 2;
    final len = 2 + rng.nextDouble() * s * 0.10;
    if (nearLine(x, y, rx, ry, rx + 1, ry + len, 1)) {
      setPx(p, s, x, y, 0x56, 0xCC, 0xF2, 120); return;
    }
  }
}

bool nearLine(int px, int py, double x1, double y1, double x2, double y2, int sw) {
  final dx = x2 - x1, dy = y2 - y1;
  final len = sqrt(dx * dx + dy * dy);
  if (len < 0.5) return false;
  return ((py - y1) * dx - (px - x1) * dy).abs() / len <= sw;
}

void setPx(Uint8List p, int s, int x, int y, int r, int g, int b, int a) {
  final i = (y * s + x) * 4;
  if (p[i+3] == 0) return;
  final alpha = a / 255.0;
  p[i] = (p[i] * (1 - alpha) + r * alpha).round().clamp(0, 255);
  p[i+1] = (p[i+1] * (1 - alpha) + g * alpha).round().clamp(0, 255);
  p[i+2] = (p[i+2] * (1 - alpha) + b * alpha).round().clamp(0, 255);
  p[i+3] = 255;
}

// PNG encoder
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