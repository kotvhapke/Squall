import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> pickImageFile() async {
  final completer = Completer<Uint8List?>();
  final fileInput = html.FileUploadInputElement()..accept = 'image/*';
  fileInput.click();
  fileInput.onChange.listen((_) async {
    final file = fileInput.files?.first;
    if (file == null) { completer.complete(null); return; }
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoadEnd.listen((_) {
      final dataUrl = reader.result as String;
      final parts = dataUrl.split(',');
      if (parts.length == 2) {
        completer.complete(base64Decode(parts[1]));
      } else {
        completer.complete(null);
      }
    });
  });
  return completer.future;
}