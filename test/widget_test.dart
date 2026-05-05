import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simon_says/main.dart';
import 'package:simon_says/settings/local_settings_repository.dart';
import 'package:simon_says/settings/neural_settings.dart';
import 'package:simon_says/stats/local_stats_repository.dart';
import 'package:simon_says/stats/stats_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('app boots after loading persisted local stats', (
    WidgetTester tester,
  ) async {
    final LocalStatsRepository repository = LocalStatsRepository();
    await repository.saveCompletedSession(
      GameSession(
        id: 'boot-seeded-session',
        mode: GameModeKey.focus,
        startedAt: DateTime.parse('2026-05-04T10:00:00Z'),
        endedAt: DateTime.parse('2026-05-04T10:02:00Z'),
        score: 420,
        bestStreak: 3,
        roundReached: 3,
        endReason: SessionEndReason.wrongTile,
      ),
    );

    await tester.pumpWidget(const NeuralRecallApp());
    expect(find.text('Loading neural profile...'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Easy mode'), findsOneWidget);
    expect(find.text('Hard Mode'), findsOneWidget);
    expect(find.text('V1.0.0'), findsOneWidget);
  });

  testWidgets('stats screen shows values loaded from local storage', (
    WidgetTester tester,
  ) async {
    final LocalStatsRepository repository = LocalStatsRepository();
    final LocalSettingsRepository settingsRepository = LocalSettingsRepository();
    await repository.saveCompletedSession(
      GameSession(
        id: 'session-1',
        mode: GameModeKey.focus,
        startedAt: DateTime.parse('2026-05-04T10:00:00Z'),
        endedAt: DateTime.parse('2026-05-04T10:02:00Z'),
        score: 1200,
        bestStreak: 8,
        roundReached: 8,
        endReason: SessionEndReason.wrongTile,
      ),
    );
    await repository.saveCompletedSession(
      GameSession(
        id: 'session-2',
        mode: GameModeKey.overdrive,
        startedAt: DateTime.parse('2026-05-04T11:00:00Z'),
        endedAt: DateTime.parse('2026-05-04T11:03:00Z'),
        score: 640,
        bestStreak: 5,
        roundReached: 5,
        endReason: SessionEndReason.timedOut,
      ),
    );
    await repository.saveCompletedSession(
      GameSession(
        id: 'session-3',
        mode: GameModeKey.focus,
        startedAt: DateTime.parse('2026-05-04T12:00:00Z'),
        endedAt: DateTime.parse('2026-05-04T12:04:00Z'),
        score: 560,
        bestStreak: 4,
        roundReached: 5,
        endReason: SessionEndReason.wrongTile,
      ),
    );
    await settingsRepository.saveSettings(
      const NeuralSettings(
        reducedMotion: true,
        soundEnabled: false,
        appTheme: AppThemeProfile.emberGlow,
      ),
    );

    await tester.pumpWidget(
      NeuralRecallApp(
        statsRepository: repository,
        settingsRepository: settingsRepository,
      ),
    );
    expect(find.text('Loading neural profile...'), findsOneWidget);

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.stacked_bar_chart_rounded));
    await tester.pumpAndSettle();

    expect(find.text('BEST STREAK'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('BEST SCORE'), findsOneWidget);
    expect(find.text('1,200'), findsAtLeastNWidgets(2));
    expect(find.text('TOTAL SESSIONS'), findsOneWidget);
    expect(find.text('3'), findsAtLeastNWidgets(1));
    expect(find.text('SCORE MEAN'), findsOneWidget);
    expect(find.text('800'), findsOneWidget);
    expect(find.text('ROUND MEAN'), findsOneWidget);
    expect(find.text('6'), findsAtLeastNWidgets(1));
    expect(find.text('FOCUS BEST'), findsOneWidget);
    expect(find.text('1,200'), findsAtLeastNWidgets(2));
    expect(find.text('OVERDRIVE BEST'), findsOneWidget);
    expect(find.text('640'), findsAtLeastNWidgets(1));
    expect(find.text('LAST PLAYED'), findsOneWidget);
    expect(find.text('May 4, 2026'), findsOneWidget);
    expect(find.text('LOCAL LEADERBOARD'), findsOneWidget);
    expect(find.text('Top saved runs'), findsOneWidget);
    expect(find.text('Recent sessions'), findsOneWidget);
    expect(find.text('Wrong tile'), findsAtLeastNWidgets(1));
    expect(find.text('Timer expired'), findsAtLeastNWidgets(1));
    expect(find.text('REACTION AVG'), findsNothing);
    expect(find.text('COMPLETION RATE'), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_rounded).hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('Ember Glow'), findsOneWidget);
    expect(find.textContaining('Current theme: Ember Glow'), findsOneWidget);
  });
}
