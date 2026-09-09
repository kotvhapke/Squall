import 'package:shared_preferences/shared_preferences.dart';

abstract class SettingsPersistence {
  String? get(String key);
  void set(String key, String value);
}

SharedPreferences? _sharedPrefs;

/// Called once at startup BEFORE any SettingsProvider is created.
Future<void> initSettingsStorage() async {
  _sharedPrefs = await SharedPreferences.getInstance();
}

class StoragePersistence extends SettingsPersistence {
  @override
  String? get(String key) {
    try { return _sharedPrefs?.getString(key); } catch (_) { return null; }
  }

  @override
  void set(String key, String value) {
    try { _sharedPrefs?.setString(key, value); } catch (_) {}
  }
}

SettingsPersistence createSettingsPersistence() => StoragePersistence();
