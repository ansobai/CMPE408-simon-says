import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:simon_says/main.dart';
import 'package:simon_says/stats/stats_models.dart';
import 'package:simon_says/stats/stats_repository.dart';

void main() {
  testWidgets('app loads persisted best streak before showing stats', (
    WidgetTester tester,
  ) async {
    final _FakeStatsRepository repository = _FakeStatsRepository(
      stats: PlayerStats(
        bestStreak: 8,
        bestScore: 1200,
        bestScoreByMode: <GameModeKey, int>{
          GameModeKey.focus: 1200,
          GameModeKey.overdrive: 640,
        },
        totalSessions: 3,
        totalScore: 2400,
        totalRoundsReached: 18,
        lastPlayedAt: DateTime.parse('2026-05-04T11:03:00Z'),
      ),
    );

    await tester.pumpWidget(NeuralRecallApp(statsRepository: repository));
    expect(find.text('Loading neural profile...'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Easy mode'), findsOneWidget);
    expect(find.text('Hard Mode'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stacked_bar_chart_rounded));
    await tester.pumpAndSettle();

    expect(find.text('BEST STREAK'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });
}

class _FakeStatsRepository extends StatsRepository {
  _FakeStatsRepository({required this.stats});

  final PlayerStats stats;

  @override
  Future<PlayerStats> loadStats() async => stats;

  @override
  Future<List<GameSession>> loadSessions() async => const <GameSession>[];

  @override
  Future<void> saveCompletedSession(GameSession session) async {}
}
