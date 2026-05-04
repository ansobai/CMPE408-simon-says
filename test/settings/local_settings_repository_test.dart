import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simon_says/settings/local_settings_repository.dart';
import 'package:simon_says/settings/neural_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('LocalSettingsRepository', () {
    test('returns defaults when storage has no data', () async {
      final LocalSettingsRepository repository = LocalSettingsRepository();

      final NeuralSettings settings = await repository.loadSettings();

      expect(settings.hapticsEnabled, isTrue);
      expect(settings.reducedMotion, isFalse);
      expect(settings.trainingHintsEnabled, isTrue);
      expect(settings.focusAssistEnabled, isFalse);
      expect(settings.confirmResetEnabled, isTrue);
      expect(settings.appTheme, AppThemeStyle.neon);
    });

    test('persists settings for the next app launch', () async {
      final LocalSettingsRepository writer = LocalSettingsRepository();
      const NeuralSettings savedSettings = NeuralSettings(
        hapticsEnabled: false,
        reducedMotion: true,
        trainingHintsEnabled: false,
        focusAssistEnabled: true,
        confirmResetEnabled: false,
        appTheme: AppThemeStyle.sunset,
      );

      await writer.saveSettings(savedSettings);

      final LocalSettingsRepository reader = LocalSettingsRepository();
      final NeuralSettings restoredSettings = await reader.loadSettings();

      expect(restoredSettings.hapticsEnabled, isFalse);
      expect(restoredSettings.reducedMotion, isTrue);
      expect(restoredSettings.trainingHintsEnabled, isFalse);
      expect(restoredSettings.focusAssistEnabled, isTrue);
      expect(restoredSettings.confirmResetEnabled, isFalse);
      expect(restoredSettings.appTheme, AppThemeStyle.sunset);
    });
  });
}
