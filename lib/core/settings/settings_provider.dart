import 'package:flutter/material.dart';
import 'persistence.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsPersistence _store;

  bool _reducedEffects = false;
  late Locale _locale;
  double _masterVolume = 80;
  double _micSensitivity = 60;
  bool _pushToTalk = false;
  bool _showOnlineOnly = false;
  bool _soundOnNotification = true;
  bool _enableVoiceActivity = true;

  bool get reducedEffects => _reducedEffects;
  Locale get locale => _locale;
  double get masterVolume => _masterVolume;
  double get micSensitivity => _micSensitivity;
  bool get pushToTalk => _pushToTalk;
  bool get showOnlineOnly => _showOnlineOnly;
  bool get soundOnNotification => _soundOnNotification;
  bool get enableVoiceActivity => _enableVoiceActivity;

  SettingsProvider({SettingsPersistence? store})
      : _store = store ?? createSettingsPersistence(),
        _locale = const Locale('en') {
    _load();
  }

  void _load() {
    _reducedEffects = _store.get('squall_reduced') == 'true';
    final lang = _store.get('squall_lang');
    if (lang != null) _locale = Locale(lang);
    _masterVolume = double.tryParse(_store.get('squall_volume') ?? '') ?? 80;
    _micSensitivity = double.tryParse(_store.get('squall_mic') ?? '') ?? 60;
    _pushToTalk = _store.get('squall_ptt') == 'true';
    _showOnlineOnly = _store.get('squall_online') == 'true';
    _soundOnNotification = _store.get('squall_sound') != 'false';
    _enableVoiceActivity = _store.get('squall_vad') != 'false';
  }

  void setReducedEffects(bool value) {
    if (_reducedEffects != value) {
      _reducedEffects = value;
      _store.set('squall_reduced', value.toString());
      notifyListeners();
    }
  }

  void setLocale(Locale locale) {
    if (_locale != locale) {
      _locale = locale;
      _store.set('squall_lang', locale.languageCode);
      notifyListeners();
    }
  }

  void setMasterVolume(double value) {
    _masterVolume = value;
    _store.set('squall_volume', value.toString());
    notifyListeners();
  }

  void setMicSensitivity(double value) {
    _micSensitivity = value;
    _store.set('squall_mic', value.toString());
    notifyListeners();
  }

  void setPushToTalk(bool value) {
    _pushToTalk = value;
    _store.set('squall_ptt', value.toString());
    notifyListeners();
  }

  void setShowOnlineOnly(bool value) {
    _showOnlineOnly = value;
    _store.set('squall_online', value.toString());
    notifyListeners();
  }

  void setSoundOnNotification(bool value) {
    _soundOnNotification = value;
    _store.set('squall_sound', value.toString());
    notifyListeners();
  }

  void setEnableVoiceActivity(bool value) {
    _enableVoiceActivity = value;
    _store.set('squall_vad', value.toString());
    notifyListeners();
  }
}