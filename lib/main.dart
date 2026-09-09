import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squall/app.dart';
import 'package:squall/core/supabase_config.dart';
import 'package:squall/core/fullscreen_service.dart';
import 'package:squall/core/settings/settings_provider.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.isConfigured) {
    runApp(const SquallApp());
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabaseAnonKey,
  );

  // Restore saved fullscreen preference.
  try {
    await windowManager.ensureInitialized();
    final prefs = SettingsProvider();
    await FullscreenService.apply(prefs.isFullscreen);
  } catch (_) {}

  runApp(const SquallApp());
}