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

  testWidgets('app boots after loading a signed-in local profile', (
    WidgetTester tester,
  ) async {
    final user = AppUser(
      id: 1,
      username: 'bara',
      score: 420,
      createdAt: DateTime.parse('2026-05-04T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-04T10:02:00Z'),
      lastPlayedAt: DateTime.parse('2026-05-04T10:02:00Z'),
    );
    final sessions = <GameSession>[
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
    ];

    await tester.pumpWidget(
      NeuralRecallApp(
        authRepository: _FakeAuthRepository(currentUser: user),
        statsRepository: _FakeStatsRepository(
          sessionsByUser: <int, List<GameSession>>{user.id: sessions},
          leaderboardUsers: <AppUser>[user],
        ),
        settingsRepository: const _FakeSettingsRepository(),
      ),
    );
    expect(find.text('Loading neural profile...'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Easy mode'), findsOneWidget);
    expect(find.text('Hard Mode'), findsOneWidget);
    expect(find.text('V1.0.0'), findsOneWidget);
  });

  testWidgets('stats screen shows values loaded from the local app state', (
    WidgetTester tester,
  ) async {
    final user = AppUser(
      id: 1,
      username: 'bara',
      score: 1200,
      createdAt: DateTime.parse('2026-05-04T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-04T12:04:00Z'),
      lastPlayedAt: DateTime.parse('2026-05-04T12:04:00Z'),
    );
    final userTwo = AppUser(
      id: 2,
      username: 'amro',
      score: 1600,
      createdAt: DateTime.parse('2026-05-04T13:00:00Z'),
      updatedAt: DateTime.parse('2026-05-04T13:02:00Z'),
      lastPlayedAt: DateTime.parse('2026-05-04T13:02:00Z'),
    );
    final sessions = <GameSession>[
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
    ];

    await tester.pumpWidget(
      NeuralRecallApp(
        authRepository: _FakeAuthRepository(currentUser: user),
        statsRepository: _FakeStatsRepository(
          sessionsByUser: <int, List<GameSession>>{user.id: sessions},
          leaderboardUsers: <AppUser>[userTwo, user],
        ),
        settingsRepository: const _FakeSettingsRepository(
          settings: NeuralSettings(
            reducedMotion: true,
            soundEnabled: false,
            appTheme: AppThemeProfile.emberGlow,
          ),
        ),
      ),
    );
    expect(find.text('Loading neural profile...'), findsOneWidget);

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.stacked_bar_chart_rounded));
    await tester.pumpAndSettle();

    expect(find.text('BEST STREAK'), findsOneWidget);
    expect(find.text('8'), findsAtLeastNWidgets(1));
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
    expect(find.text('PLAYER LEADERBOARD'), findsOneWidget);
    expect(find.text('Registered players'), findsOneWidget);
    expect(find.text('bara'), findsOneWidget);
    expect(find.text('amro'), findsOneWidget);
    expect(find.text('Current player'), findsOneWidget);
    expect(find.text('YOUR RECENT RUNS'), findsOneWidget);
    expect(find.text('Recent sessions'), findsOneWidget);
    expect(find.text('Wrong tile'), findsAtLeastNWidgets(1));
    expect(find.text('Timer expired'), findsAtLeastNWidgets(1));

    await tester.tap(find.byIcon(Icons.settings_rounded).hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('Ember Glow'), findsOneWidget);
    expect(find.textContaining('Current theme: Ember Glow'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('bara'), findsOneWidget);
  });
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({required AppUser? currentUser})
    : _currentUser = currentUser;

  AppUser? _currentUser;

  @override
  Future<AppUser?> loadUserById(int userId) async {
    return _currentUser?.id == userId ? _currentUser : null;
  }

  @override
  Future<AppUser?> restoreSession() async => _currentUser;

  @override
  Future<AppUser> signIn({
    required String username,
    required String password,
  }) async => _currentUser!;

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<void> deleteAccount() async {
    _currentUser = null;
  }

  @override
  Future<AppUser> signUp({
    required String username,
    required String password,
  }) async => _currentUser!;
}

class _FakeStatsRepository extends StatsRepository {
  _FakeStatsRepository({
    required this.sessionsByUser,
    required this.leaderboardUsers,
  });

  final Map<int, List<GameSession>> sessionsByUser;
  final List<AppUser> leaderboardUsers;

  @override
  Future<List<AppUser>> loadLeaderboardUsers({int? limit}) async {
    return limit == null
        ? List<AppUser>.unmodifiable(leaderboardUsers)
        : leaderboardUsers.take(limit).toList(growable: false);
  }

  @override
  Future<PlayerStats> loadStatsForUser(int userId) async {
    return PlayerStats.fromSessions(
      sessionsByUser[userId] ?? const <GameSession>[],
    );
  }

  @override
  Future<List<GameSession>> loadSessionsForUser(int userId) async {
    return List<GameSession>.unmodifiable(
      sessionsByUser[userId] ?? const <GameSession>[],
    );
  }

  @override
  Future<void> saveCompletedSession({
    required int userId,
    required GameSession session,
  }) async {}
}

class _FakeSettingsRepository extends SettingsRepository {
  const _FakeSettingsRepository({this.settings = const NeuralSettings()});

  final NeuralSettings settings;

  @override
  Future<NeuralSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(NeuralSettings settings) async {}
}
