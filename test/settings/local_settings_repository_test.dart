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
      expect(settings.confirmResetEnabled, isTrue);
      expect(settings.soundEnabled, isTrue);
      expect(settings.soundLevel, 0.76);
      expect(settings.sequenceSpeed, 1.0);
      expect(settings.overdriveWindowScale, 1.0);
      expect(settings.appTheme, AppThemeProfile.neuralBlue);
    });

    test('persists settings for the next app launch', () async {
      final LocalSettingsRepository writer = LocalSettingsRepository();
      const NeuralSettings savedSettings = NeuralSettings(
        hapticsEnabled: false,
        reducedMotion: true,
        trainingHintsEnabled: false,
        confirmResetEnabled: false,
        soundEnabled: false,
        soundLevel: 0.42,
        sequenceSpeed: 1.2,
        overdriveWindowScale: 0.9,
        appTheme: AppThemeProfile.emberGlow,
      );

      await writer.saveSettings(savedSettings);

      final LocalSettingsRepository reader = LocalSettingsRepository();
      final NeuralSettings restoredSettings = await reader.loadSettings();

      expect(restoredSettings.hapticsEnabled, isFalse);
      expect(restoredSettings.reducedMotion, isTrue);
      expect(restoredSettings.trainingHintsEnabled, isFalse);
      expect(restoredSettings.confirmResetEnabled, isFalse);
      expect(restoredSettings.soundEnabled, isFalse);
      expect(restoredSettings.soundLevel, 0.42);
      expect(restoredSettings.sequenceSpeed, 1.2);
      expect(restoredSettings.overdriveWindowScale, 0.9);
      expect(restoredSettings.appTheme, AppThemeProfile.emberGlow);
    });
  });
}
