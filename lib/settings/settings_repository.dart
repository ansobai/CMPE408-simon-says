import 'neural_settings.dart';

abstract class SettingsRepository {
  const SettingsRepository();

  Future<NeuralSettings> loadSettings();

  Future<void> saveSettings(NeuralSettings settings);
}
