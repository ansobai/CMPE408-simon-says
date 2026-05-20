import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'neural_settings.dart';
import 'settings_repository.dart';

class LocalSettingsRepository extends SettingsRepository {
  const LocalSettingsRepository();

  static const String _settingsKey = 'settings.neural';

  @override
  Future<NeuralSettings> loadSettings() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? rawSettings = preferences.getString(_settingsKey);
    if (rawSettings == null || rawSettings.isEmpty) {
      return const NeuralSettings();
    }

    return NeuralSettings.fromMap(_decodeMap(rawSettings));
  }

  @override
  Future<void> saveSettings(NeuralSettings settings) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_settingsKey, jsonEncode(settings.toMap()));
  }

  Map<String, Object?> _decodeMap(String rawValue) {
    return (jsonDecode(rawValue) as Map<Object?, Object?>)
        .cast<String, Object?>();
  }
}
