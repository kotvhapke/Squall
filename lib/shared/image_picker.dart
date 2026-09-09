import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Opens a native file picker and returns the selected image bytes,
/// or null if the user cancels. Works on all platforms.
Future<Uint8List?> pickImageFile() async {
  final files = await FilePicker.pickFiles(type: FileType.image);
  if (files == null || files.isEmpty) return null;
  return await files.first.readAsBytes();
}
