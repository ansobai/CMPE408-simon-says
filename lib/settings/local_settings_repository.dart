import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'neural_settings.dart';
import 'settings_repository.dart';

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();

class LocalSettingsRepository extends SettingsRepository {
  LocalSettingsRepository({SharedPreferencesLoader? preferencesLoader})
    : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String _settingsKey = 'settings.neural';

  final SharedPreferencesLoader _preferencesLoader;

  SharedPreferences? _preferences;

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ??= await _preferencesLoader();
  }

  @override
  Future<NeuralSettings> loadSettings() async {
    final SharedPreferences preferences = await _getPreferences();
    final String? rawSettings = preferences.getString(_settingsKey);
    if (rawSettings == null || rawSettings.isEmpty) {
      return const NeuralSettings();
    }

    return NeuralSettings.fromMap(_decodeMap(rawSettings));
  }

  @override
  Future<void> saveSettings(NeuralSettings settings) async {
    final SharedPreferences preferences = await _getPreferences();
    await preferences.setString(_settingsKey, jsonEncode(settings.toMap()));
  }

  Map<String, Object?> _decodeMap(String rawValue) {
    return (jsonDecode(rawValue) as Map<Object?, Object?>)
        .cast<String, Object?>();
  }
}
