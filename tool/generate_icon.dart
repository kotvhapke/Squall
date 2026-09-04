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
  final cx = s / 2, cy = s / 2;
  final cornerR = s * 0.10;

  for (int y = 0; y < s; y++) {
    for (int x = 0; x < s; x++) {
      final i = (y * s + x) * 4;

      // Rounded square mask (like a launcher icon)
      bool inside = true;
      if (x < cornerR && y < cornerR) inside = (x - cornerR).abs() + (y - cornerR).abs() <= cornerR;
      else if (x >= s - cornerR && y < cornerR) inside = (x - (s - 1 - cornerR)).abs() + (y - cornerR).abs() <= cornerR;
      else if (x < cornerR && y >= s - cornerR) inside = (x - cornerR).abs() + (y - (s - 1 - cornerR)).abs() <= cornerR;
      else if (x >= s - cornerR && y >= s - cornerR) {
        inside = (x - (s - 1 - cornerR)).abs() + (y - (s - 1 - cornerR)).abs() <= cornerR;
      }

      if (!inside) {
        pixels[i] = 0; pixels[i+1] = 0; pixels[i+2] = 0; pixels[i+3] = 0;
        continue;
      }

      // Solid near-black background (as in the reference logo)
      pixels[i] = 5; pixels[i+1] = 7; pixels[i+2] = 12; pixels[i+3] = 255;

      // Subtle electric-blue ring on the edge (Squall accent), thin
      final edge = s * 0.03;
      if (x < edge || y < edge || x >= s - edge || y >= s - edge) {
        // keep dark
      }

      // Draw the white rounded-rect "S"
      drawS(pixels, s, x, y, cx, cy);
    }
  }
  return pngEncode(pixels, s, s);
}

void drawS(Uint8List p, int s, int x, int y, double cx, double cy) {
  final pad = s * 0.14;      // top/bottom padding
  final w = s * 0.26;        // bar height (thickness)
  final r = s * 0.05;        // corner radius
  final half = s / 2;

  // Three bars forming the geometric "S":
  //   top bar    -> right half
  //   middle bar -> left-ish bridge
  //   bottom bar -> left half
  final bars = <List<double>>[
    // top: from center-left to right
    [half - w * 0.35, pad, w * 1.55, w],
    // middle bridge
    [half - w * 0.5, half - w / 2, w * 1.15, w],
    // bottom: from left to center-right
    [pad, s - pad - w, w * 1.55, w],
  ];

  for (final bar in bars) {
    final bx = bar[0], by = bar[1], bw = bar[2], bh = bar[3];
    if (insideRRect(x, y, bx, by, bw, bh, r)) {
      setPx(p, s, x, y, 255, 255, 255, 255);
    }
  }

  // Thin electric-blue accent line under the top bar (subtle Squall touch)
  if (insideRRect(x, y, half - w * 0.35, pad + w - s * 0.008, w * 1.55, s * 0.012, s * 0.006)) {
    setPx(p, s, x, y, 0, 168, 255, 120);
  }
}

bool insideRRect(int px, int py, double rx, double ry, double rw, double rh, double rr) {
  if (px < rx || px > rx + rw || py < ry || py > ry + rh) return false;
  final dx = min((px - rx).abs(), (px - (rx + rw)).abs()).toDouble();
  final dy = min((py - ry).abs(), (py - (ry + rh)).abs()).toDouble();
  if (dx <= rr && dy <= rr) {
    return dx * dx + dy * dy <= rr * rr;
  }
  return true;
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