import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simon_says/auth/auth_models.dart';
import 'package:simon_says/auth/auth_repository.dart';
import 'package:simon_says/main.dart';
import 'package:simon_says/settings/neural_settings.dart';
import 'package:simon_says/settings/settings_repository.dart';
import 'package:simon_says/stats/stats_models.dart';
import 'package:simon_says/stats/stats_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'stats screen shows current user rank and users-table leaderboard',
    (WidgetTester tester) async {
      final AppUser currentUser = AppUser(
        id: 2,
        username: 'bara',
        score: 1200,
        createdAt: DateTime.parse('2026-05-04T10:00:00Z'),
        updatedAt: DateTime.parse('2026-05-04T12:04:00Z'),
        lastPlayedAt: DateTime.parse('2026-05-04T12:04:00Z'),
      );
      final List<AppUser> leaderboardUsers = <AppUser>[
        AppUser(
          id: 1,
          username: 'amro',
          score: 1600,
          createdAt: DateTime.parse('2026-05-04T09:00:00Z'),
          updatedAt: DateTime.parse('2026-05-04T13:02:00Z'),
          lastPlayedAt: DateTime.parse('2026-05-04T13:02:00Z'),
        ),
        currentUser,
        AppUser(
          id: 3,
          username: 'lina',
          score: 800,
          createdAt: DateTime.parse('2026-05-04T08:00:00Z'),
          updatedAt: DateTime.parse('2026-05-04T11:15:00Z'),
          lastPlayedAt: DateTime.parse('2026-05-04T11:15:00Z'),
        ),
      ];
      final List<GameSession> sessions = <GameSession>[
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
      ];

      await tester.pumpWidget(
        NeuralRecallApp(
          authRepository: _LeaderboardAuthRepository(currentUser),
          statsRepository: _LeaderboardStatsRepository(
            sessions: sessions,
            leaderboardUsers: leaderboardUsers,
          ),
          settingsRepository: const _LeaderboardSettingsRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.stacked_bar_chart_rounded));
      await tester.pumpAndSettle();

      expect(find.text('GLOBAL RANK'), findsOneWidget);
      expect(find.text('#2 of 3'), findsOneWidget);
      expect(find.text('PROFILE SCORE'), findsOneWidget);
      expect(find.text('1,200'), findsAtLeastNWidgets(1));
      expect(find.text('Current profile'), findsOneWidget);
    },
  );
}

class _LeaderboardAuthRepository extends AuthRepository {
  const _LeaderboardAuthRepository(this.user);

  final AppUser user;

  @override
  Future<AppUser?> loadUserById(int userId) async {
    return userId == user.id ? user : null;
  }

  @override
  Future<AppUser?> restoreSession() async => user;

  @override
  Future<AppUser> signIn({
    required String username,
    required String password,
  }) async => user;

  @override
  Future<void> signOut() async {}

  @override
  Future<AppUser> signUp({
    required String username,
    required String password,
  }) async => user;
}

class _LeaderboardStatsRepository extends StatsRepository {
  const _LeaderboardStatsRepository({
    required this.sessions,
    required this.leaderboardUsers,
  });

  final List<GameSession> sessions;
  final List<AppUser> leaderboardUsers;

  @override
  Future<List<AppUser>> loadLeaderboardUsers({int limit = 10}) async {
    return leaderboardUsers.take(limit).toList(growable: false);
  }

  @override
  Future<PlayerStats> loadStatsForUser(int userId) async {
    return PlayerStats.fromSessions(sessions);
  }

  @override
  Future<List<GameSession>> loadSessionsForUser(int userId) async {
    return sessions;
  }

  @override
  Future<void> saveCompletedSession({
    required int userId,
    required GameSession session,
  }) async {}
}

class _LeaderboardSettingsRepository extends SettingsRepository {
  const _LeaderboardSettingsRepository();

  @override
  Future<NeuralSettings> loadSettings() async => const NeuralSettings();

  @override
  Future<void> saveSettings(NeuralSettings settings) async {}
}
