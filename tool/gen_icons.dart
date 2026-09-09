import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() {
  final src = File('assets/branding/squall-icon-user.png').readAsBytesSync();
  final original = img.decodePng(src)!;

  final sizes = [48, 64, 96, 128, 192, 256, 512];

  // favicons: 48, 64
  for (final s in [48, 64, 96]) {
    final resized = img.copyResize(original, width: s, height: s);
    File('web/favicon-$s.png').writeAsBytesSync(img.encodePng(resized));
  }
  // 48 favicon as default
  final fav48 = img.copyResize(original, width: 48, height: 48);
  File('web/favicon.png').writeAsBytesSync(img.encodePng(fav48));

  // PWA icons
  for (final s in [192, 512]) {
    final resized = img.copyResize(original, width: s, height: s);
    File('web/icons/Icon-$s.png').writeAsBytesSync(img.encodePng(resized));
    File('web/icons/Icon-maskable-$s.png').writeAsBytesSync(img.encodePng(resized));
  }

  print('OK: favicon 48/64/96 + PWA icons regenerated');
}