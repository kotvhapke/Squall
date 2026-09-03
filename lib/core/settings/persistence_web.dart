import 'dart:html' as html;

abstract class SettingsPersistence {
  String? get(String key);
  void set(String key, String value);
}

class WebPersistence extends SettingsPersistence {
  @override
  String? get(String key) {
    try { return html.window.localStorage[key]; } catch (_) { return null; }
  }
  @override
  void set(String key, String value) {
    try { html.window.localStorage[key] = value; } catch (_) {}
  }
}

SettingsPersistence createSettingsPersistence() => WebPersistence();