import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() {
  final src = File('assets/branding/squall-icon-user.png').readAsBytesSync();
  final original = img.decodePng(src)!;

  // Make black background transparent: for each pixel, luminance of black background
  // becomes transparent, keep the bright S opaque. Use distance from black.
  final w = original.width, h = original.height;
  final clear = img.Image(width: w, height: h);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = original.getPixel(x, y);
      final r = p.r, g = p.g, b = p.b;
      // brightness
      final lum = (0.299 * r + 0.587 * g + 0.114 * b);
      // alpha based on how bright the pixel is (so dark background -> transparent)
      int a = (lum).round().clamp(0, 255);
      clear.setPixelRgba(x, y, r.toInt(), g.toInt(), b.toInt(), a);
    }
  }

  // Save transparent versions + regenerate ico + web icons
  File('assets/branding/squall-icon-user.png').writeAsBytesSync(img.encodePng(clear));

  // Regenerate Windows .ico (9 sizes)
  final sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256];
  final pngs = <int, Uint8List>{};
  for (final s in sizes) {
    final rs = img.copyResize(clear, width: s, height: s);
    pngs[s] = Uint8List.fromList(img.encodePng(rs));
  }
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(encodeIco(pngs));

  // Web icons
  for (final s in [192, 512]) {
    final rs = img.copyResize(clear, width: s, height: s);
    File('web/icons/Icon-$s.png').writeAsBytesSync(img.encodePng(rs));
    File('web/icons/Icon-maskable-$s.png').writeAsBytesSync(img.encodePng(rs));
  }
  // logos for web/landing
  File('web/logo.png').writeAsBytesSync(img.encodePng(clear));
  File('web/favicon.png').writeAsBytesSync(img.encodePng(img.copyResize(clear, width: 48, height: 48)));

  print('OK: transparent icon + ico + web icons done');
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
  return Uint8List.fromList([...out.toBytes(), ...dir.toBytes(), ...data.toBytes()]);
}

extension _BB on BytesBuilder {
  void addByte(int v) => add([v & 0xFF]);
  void addUint16(int v) { addByte(v); addByte(v >> 8); }
  void addUint32(int v) { addByte(v); addByte(v >> 8); addByte(v >> 16); addByte(v >> 24); }
}
