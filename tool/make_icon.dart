import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart';

void main() {
  final src = decodeImage(File('assets/branding/squall-icon-user.png').readAsBytesSync())!;
  final sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256];
  final pngs = <int, Uint8List>{};

  for (final s in sizes) {
    final resized = copyResize(src, width: s, height: s, interpolation: Interpolation.average);
    pngs[s] = Uint8List.fromList(encodePng(resized));
  }

  // Also save 256 as branding png
  File('assets/branding/squall-icon-256.png').writeAsBytesSync(pngs[256]!);

  final ico = encodeIco(pngs);
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(ico);
  print('OK: ${ico.length} bytes, ${sizes.length} sizes');
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