import 'package:web/web.dart' as web;

abstract class SettingsPersistence {
  String? get(String key);
  void set(String key, String value);
}

class WebPersistence extends SettingsPersistence {
  @override
  String? get(String key) {
    try { return web.window.localStorage.getItem(key); } catch (_) { return null; }
  }
  @override
  void set(String key, String value) {
    try { web.window.localStorage.setItem(key, value); } catch (_) {}
  }
}

SettingsPersistence createSettingsPersistence() => WebPersistence();

Future<void> initSettingsStorage() async {}