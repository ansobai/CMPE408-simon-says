import 'package:flutter_test/flutter_test.dart';
import 'package:simon_says/stats/stats_models.dart';

void main() {
  group('GameSessionCollections', () {
    final List<GameSession> sessions = <GameSession>[
      _session(
        id: 'focus-top',
        mode: GameModeKey.focus,
        score: 2500,
        bestStreak: 12,
        roundReached: 10,
        endedAt: '2026-05-05T10:05:00Z',
      ),
      _session(
        id: 'overdrive-mid',
        mode: GameModeKey.overdrive,
        score: 1800,
        bestStreak: 7,
        roundReached: 6,
        endedAt: '2026-05-05T10:08:00Z',
      ),
      _session(
        id: 'focus-recent',
        mode: GameModeKey.focus,
        score: 1800,
        bestStreak: 8,
        roundReached: 7,
        endedAt: '2026-05-05T10:09:00Z',
      ),
      _session(
        id: 'focus-older',
        mode: GameModeKey.focus,
        score: 1800,
        bestStreak: 8,
        roundReached: 6,
        endedAt: '2026-05-05T10:02:00Z',
      ),
    ];

    test(
      'leaderboard sorts by score, then streak, then round, then recency',
      () {
        final List<GameSession> leaderboard = sessions.leaderboard(limit: 4);

        expect(leaderboard.map((GameSession session) => session.id), <String>[
          'focus-top',
          'focus-recent',
          'focus-older',
          'overdrive-mid',
        ]);
      },
    );

    test('leaderboard can filter by mode', () {
      final List<GameSession> leaderboard = sessions.leaderboard(
        mode: GameModeKey.focus,
        limit: 4,
      );

      expect(leaderboard.map((GameSession session) => session.id), <String>[
        'focus-top',
        'focus-recent',
        'focus-older',
      ]);
    });

    test('recent runs returns latest sessions first', () {
      final List<GameSession> recentRuns = sessions.recentRuns(limit: 3);

      expect(recentRuns.map((GameSession session) => session.id), <String>[
        'focus-recent',
        'overdrive-mid',
        'focus-top',
      ]);
    });
  });
}

GameSession _session({
  required String id,
  required GameModeKey mode,
  required int score,
  required int bestStreak,
  required int roundReached,
  required String endedAt,
}) {
  final DateTime endedTime = DateTime.parse(endedAt);
  return GameSession(
    id: id,
    mode: mode,
    startedAt: endedTime.subtract(const Duration(minutes: 2)),
    endedAt: endedTime,
    score: score,
    bestStreak: bestStreak,
    roundReached: roundReached,
    endReason: SessionEndReason.wrongTile,
  );
}
