import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simon_says/stats/local_stats_repository.dart';
import 'package:simon_says/stats/stats_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('LocalStatsRepository', () {
    test('returns empty stats when storage has no data', () async {
      final LocalStatsRepository repository = LocalStatsRepository();

      final PlayerStats stats = await repository.loadStats();
      final List<GameSession> sessions = await repository.loadSessions();

      expect(stats.bestStreak, 0);
      expect(stats.bestScore, 0);
      expect(stats.bestScoreByMode[GameModeKey.focus], 0);
      expect(stats.bestScoreByMode[GameModeKey.overdrive], 0);
      expect(stats.totalSessions, 0);
      expect(sessions, isEmpty);
    });

    test('loads previously persisted stats without recomputing them', () async {
      final SharedPreferencesStatsStore store = SharedPreferencesStatsStore();
      final PlayerStats persistedStats = PlayerStats(
        bestStreak: 9,
        bestScore: 3100,
        bestScoreByMode: <GameModeKey, int>{
          GameModeKey.focus: 1400,
          GameModeKey.overdrive: 3100,
        },
        totalSessions: 12,
        totalScore: 16800,
        totalRoundsReached: 84,
        lastPlayedAt: DateTime.parse('2026-05-04T12:00:00Z'),
      );

      await store.writeStats(persistedStats);
      await store.writeSessions(<GameSession>[_sessionOne()]);

      final LocalStatsRepository repository =
          LocalStatsRepository(store: store);
      final PlayerStats stats = await repository.loadStats();

      expect(stats.bestStreak, persistedStats.bestStreak);
      expect(stats.bestScore, persistedStats.bestScore);
      expect(
        stats.bestScoreByMode[GameModeKey.focus],
        persistedStats.bestScoreByMode[GameModeKey.focus],
      );
      expect(
        stats.bestScoreByMode[GameModeKey.overdrive],
        persistedStats.bestScoreByMode[GameModeKey.overdrive],
      );
      expect(stats.totalSessions, persistedStats.totalSessions);
      expect(stats.totalScore, persistedStats.totalScore);
      expect(stats.totalRoundsReached, persistedStats.totalRoundsReached);
      expect(stats.lastPlayedAt, persistedStats.lastPlayedAt);
    });

    test(
        'derives and persists stats from stored sessions when stats are missing',
        () async {
      final SharedPreferencesStatsStore store = SharedPreferencesStatsStore();
      await store.writeSessions(<GameSession>[_sessionOne(), _sessionTwo()]);

      final LocalStatsRepository repository =
          LocalStatsRepository(store: store);
      final PlayerStats stats = await repository.loadStats();
      final PlayerStats? persistedStats = await store.readStats();

      expect(stats.bestStreak, 6);
      expect(stats.bestScore, 21);
      expect(stats.bestScoreByMode[GameModeKey.focus], 14);
      expect(stats.bestScoreByMode[GameModeKey.overdrive], 21);
      expect(stats.totalSessions, 2);
      expect(stats.totalScore, 35);
      expect(stats.totalRoundsReached, 10);
      expect(stats.lastPlayedAt, DateTime.parse('2026-05-04T11:03:00Z'));
      expect(stats.averageScore, 17.5);
      expect(stats.averageRoundsReached, 5);
      expect(persistedStats?.toMap(), stats.toMap());
    });

    test('persists completed sessions and derived stats locally', () async {
      final LocalStatsRepository writer = LocalStatsRepository();
      final GameSession sessionOne = _sessionOne();
      final GameSession sessionTwo = _sessionTwo();

      await writer.saveCompletedSession(sessionOne);
      await writer.saveCompletedSession(sessionTwo);

      final LocalStatsRepository reader = LocalStatsRepository();
      final PlayerStats stats = await reader.loadStats();
      final List<GameSession> sessions = await reader.loadSessions();

      expect(sessions, hasLength(2));
      expect(sessions.map((GameSession session) => session.id), <String>[
        'session-1',
        'session-2',
      ]);
      expect(stats.bestStreak, 6);
      expect(stats.bestScore, 21);
      expect(stats.bestScoreByMode[GameModeKey.focus], 14);
      expect(stats.bestScoreByMode[GameModeKey.overdrive], 21);
      expect(stats.totalSessions, 2);
      expect(stats.totalScore, 35);
      expect(stats.totalRoundsReached, 10);
      expect(stats.lastPlayedAt, DateTime.parse('2026-05-04T11:03:00Z'));
      expect(stats.averageScore, 17.5);
      expect(stats.averageRoundsReached, 5);
    });
  });
}

GameSession _sessionOne() {
  return GameSession(
    id: 'session-1',
    mode: GameModeKey.focus,
    startedAt: DateTime.parse('2026-05-04T10:00:00Z'),
    endedAt: DateTime.parse('2026-05-04T10:02:00Z'),
    score: 14,
    bestStreak: 4,
    roundReached: 4,
    endReason: SessionEndReason.wrongTile,
  );
}

GameSession _sessionTwo() {
  return GameSession(
    id: 'session-2',
    mode: GameModeKey.overdrive,
    startedAt: DateTime.parse('2026-05-04T11:00:00Z'),
    endedAt: DateTime.parse('2026-05-04T11:03:00Z'),
    score: 21,
    bestStreak: 6,
    roundReached: 6,
    endReason: SessionEndReason.timedOut,
  );
}
