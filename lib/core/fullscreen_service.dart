import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

/// Cross-platform fullscreen helper. Uses window_manager on desktop;
/// on web it's a no-op (browser handles fullscreen separately).
class FullscreenService {
  static Future<void> apply(bool fullscreen) async {
    if (kIsWeb) return;
    try {
      if (fullscreen) {
        await windowManager.setFullScreen(true);
      } else {
        await windowManager.setFullScreen(false);
      }
    } catch (_) {}
  }
}
