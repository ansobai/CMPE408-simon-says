import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:simon_says/api/api_errors.dart';
import 'package:simon_says/auth/auth_models.dart';
import 'package:simon_says/auth/auth_repository.dart';
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

  testWidgets('stats screen shows an explicit no-data state', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(
      NeuralRecallApp(
        authRepository: _SignedInAuthRepository(),
        statsRepository: const _InMemoryStatsRepository(),
        settingsRepository: const _InMemorySettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.stacked_bar_chart_rounded));
    await tester.pumpAndSettle();

    expect(find.text('No sessions have been saved yet'), findsOneWidget);
    expect(find.text('No leaderboard entries yet'), findsOneWidget);
    expect(find.text('No session history yet'), findsOneWidget);
  });

  testWidgets('app shows a recovery notice when saved stats cannot be loaded', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(
      NeuralRecallApp(
        authRepository: _SignedInAuthRepository(),
        statsRepository: const _ThrowingStatsRepository(),
        settingsRepository: const _InMemorySettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Shared account data could not be loaded'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'sessions, stats, or leaderboard data could not be fetched',
      ),
      findsOneWidget,
    );
  });

  testWidgets('expired startup session returns to sign in with a warning', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(
      NeuralRecallApp(
        authRepository: _SignedInAuthRepository(),
        statsRepository: const _UnauthorizedStatsRepository(),
        settingsRepository: const _InMemorySettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Sign in or create a shared player account'),
      findsOneWidget,
    );
    expect(find.text('Your session expired'), findsOneWidget);
  });

  testWidgets('app shows a notice when settings cannot be persisted', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(
      NeuralRecallApp(
        authRepository: _SignedInAuthRepository(),
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

class _SignedInAuthRepository extends AuthRepository {
  _SignedInAuthRepository();

  final AppUser _user = AppUser(
    id: 1,
    username: 'bara',
    score: 0,
    createdAt: DateTime.parse('2026-05-04T10:00:00Z'),
    updatedAt: DateTime.parse('2026-05-04T10:00:00Z'),
  );

  @override
  Future<AppUser?> loadUserById(int userId) async {
    return userId == _user.id ? _user : null;
  }

  @override
  Future<AppUser?> restoreSession() async => _user;

  @override
  Future<AppUser> signIn({
    required String username,
    required String password,
  }) async => _user;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<AppUser> signUp({
    required String username,
    required String password,
  }) async => _user;
}

class _InMemoryStatsRepository extends StatsRepository {
  const _InMemoryStatsRepository();

  @override
  Future<List<AppUser>> loadLeaderboardUsers({int? limit}) async {
    return <AppUser>[];
  }

  @override
  Future<PlayerStats> loadStatsForUser(int userId) async => PlayerStats.empty();

  @override
  Future<List<GameSession>> loadSessionsForUser(int userId) async {
    return <GameSession>[];
  }

  @override
  Future<void> saveCompletedSession({
    required int userId,
    required GameSession session,
  }) async {}
}

class _ThrowingStatsRepository extends StatsRepository {
  const _ThrowingStatsRepository();

  @override
  Future<List<AppUser>> loadLeaderboardUsers({int? limit}) {
    throw const FormatException('corrupt leaderboard');
  }

  @override
  Future<PlayerStats> loadStatsForUser(int userId) {
    throw const FormatException('corrupt stats');
  }

  @override
  Future<List<GameSession>> loadSessionsForUser(int userId) {
    throw const FormatException('corrupt sessions');
  }

  @override
  Future<void> saveCompletedSession({
    required int userId,
    required GameSession session,
  }) async {}
}

class _UnauthorizedStatsRepository extends StatsRepository {
  const _UnauthorizedStatsRepository();

  @override
  Future<List<AppUser>> loadLeaderboardUsers({int? limit}) async {
    return const <AppUser>[];
  }

  @override
  Future<PlayerStats> loadStatsForUser(int userId) {
    throw const ApiUnauthorizedException();
  }

  @override
  Future<List<GameSession>> loadSessionsForUser(int userId) {
    throw const ApiUnauthorizedException();
  }

  @override
  Future<void> saveCompletedSession({
    required int userId,
    required GameSession session,
  }) async {}
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
