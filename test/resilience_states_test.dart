import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simon_says/main.dart';
import 'package:simon_says/settings/neural_settings.dart';
import 'package:simon_says/settings/settings_repository.dart';
import 'package:simon_says/stats/stats_models.dart';
import 'package:simon_says/stats/stats_repository.dart';

Future<void> _setPhoneSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('stats screen shows an explicit no-data state', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(const NeuralRecallApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.stacked_bar_chart_rounded));
    await tester.pumpAndSettle();

    expect(find.text('No sessions have been saved yet'), findsOneWidget);
    expect(find.text('No ranked runs yet'), findsOneWidget);
    expect(find.text('No session history yet'), findsOneWidget);
  });

  testWidgets('app shows a recovery notice when saved stats cannot be loaded', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(
      NeuralRecallApp(
        statsRepository: const _ThrowingStatsRepository(),
        settingsRepository: const _InMemorySettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved sessions could not be loaded'), findsOneWidget);
    expect(
      find.textContaining('stats, leaderboard, and recent run history'),
      findsOneWidget,
    );
  });

  testWidgets('app shows a notice when settings cannot be persisted', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(
      NeuralRecallApp(
        statsRepository: const _InMemoryStatsRepository(),
        settingsRepository: const _ThrowingSettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded).hitTestable().first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ember Glow'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ember Glow'));
    await tester.pumpAndSettle();

    expect(
      find.text('Settings changed, but they were not saved'),
      findsOneWidget,
    );
    expect(
      find.textContaining('will stay active until the app closes'),
      findsOneWidget,
    );
  });
}

class _InMemoryStatsRepository extends StatsRepository {
  const _InMemoryStatsRepository();

  @override
  Future<PlayerStats> loadStats() async => PlayerStats.empty();

  @override
  Future<List<GameSession>> loadSessions() async => <GameSession>[];

  @override
  Future<void> saveCompletedSession(GameSession session) async {}
}

class _ThrowingStatsRepository extends StatsRepository {
  const _ThrowingStatsRepository();

  @override
  Future<PlayerStats> loadStats() {
    throw const FormatException('corrupt stats');
  }

  @override
  Future<List<GameSession>> loadSessions() {
    throw const FormatException('corrupt sessions');
  }

  @override
  Future<void> saveCompletedSession(GameSession session) async {}
}

class _InMemorySettingsRepository extends SettingsRepository {
  const _InMemorySettingsRepository();

  @override
  Future<NeuralSettings> loadSettings() async => const NeuralSettings();

  @override
  Future<void> saveSettings(NeuralSettings settings) async {}
}

class _ThrowingSettingsRepository extends SettingsRepository {
  const _ThrowingSettingsRepository();

  @override
  Future<NeuralSettings> loadSettings() async => const NeuralSettings();

  @override
  Future<void> saveSettings(NeuralSettings settings) {
    throw const FormatException('settings write failed');
  }
}
