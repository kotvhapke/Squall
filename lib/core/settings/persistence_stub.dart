abstract class SettingsPersistence {
  String? get(String key);
  void set(String key, String value);
}

class MemoryPersistence extends SettingsPersistence {
  final _data = <String, String>{};
  @override
  String? get(String key) => _data[key];
  @override
  void set(String key, String value) => _data[key] = value;
}

SettingsPersistence createSettingsPersistence() => MemoryPersistence();