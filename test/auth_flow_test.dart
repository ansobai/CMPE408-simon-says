import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('sign up creates a shared profile and enters the app', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    final _MutableAuthRepository authRepository = _MutableAuthRepository();

    await tester.pumpWidget(
      NeuralRecallApp(
        authRepository: authRepository,
        statsRepository: const _EmptyStatsRepository(),
        settingsRepository: const _MemorySettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Sign in or create a shared player account'),
      findsOneWidget,
    );
    await tester.tap(find.text('SIGN UP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'bara');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tester.tap(find.text('CREATE PROFILE'));
    await tester.pumpAndSettle();

    expect(find.text('Easy mode'), findsOneWidget);
    expect(find.text('SIGNED IN AS BARA'), findsOneWidget);
  });

  testWidgets('sign out returns to the auth screen', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    final _MutableAuthRepository authRepository = _MutableAuthRepository(
      currentUser: AppUser(
        id: 1,
        username: 'bara',
        score: 0,
        createdAt: DateTime.parse('2026-05-04T10:00:00Z'),
        updatedAt: DateTime.parse('2026-05-04T10:00:00Z'),
      ),
    );

    await tester.pumpWidget(
      NeuralRecallApp(
        authRepository: authRepository,
        statsRepository: const _EmptyStatsRepository(),
        settingsRepository: const _MemorySettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded).hitTestable().first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('SIGN OUT'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIGN OUT'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sign in or create a shared player account'),
      findsOneWidget,
    );
    expect(find.text('Signed out'), findsOneWidget);
  });
}

class _MutableAuthRepository extends AuthRepository {
  _MutableAuthRepository({AppUser? currentUser}) : _currentUser = currentUser;

  AppUser? _currentUser;
  int _nextId = 1;

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
  }) async {
    final AppUser user =
        _currentUser ??
        AppUser(
          id: _nextId++,
          username: username,
          score: 0,
          createdAt: DateTime.parse('2026-05-04T10:00:00Z'),
          updatedAt: DateTime.parse('2026-05-04T10:00:00Z'),
        );
    _currentUser = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<AppUser> signUp({
    required String username,
    required String password,
  }) async {
    final AppUser user = AppUser(
      id: _nextId++,
      username: username.toUpperCase(),
      score: 0,
      createdAt: DateTime.parse('2026-05-04T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-04T10:00:00Z'),
    );
    _currentUser = user;
    return user;
  }
}

class _EmptyStatsRepository extends StatsRepository {
  const _EmptyStatsRepository();

  @override
  Future<List<AppUser>> loadLeaderboardUsers({int? limit}) async {
    return const <AppUser>[];
  }

  @override
  Future<PlayerStats> loadStatsForUser(int userId) async => PlayerStats.empty();

  @override
  Future<List<GameSession>> loadSessionsForUser(int userId) async {
    return const <GameSession>[];
  }

  @override
  Future<void> saveCompletedSession({
    required int userId,
    required GameSession session,
  }) async {}
}

class _MemorySettingsRepository extends SettingsRepository {
  const _MemorySettingsRepository();

  @override
  Future<NeuralSettings> loadSettings() async => const NeuralSettings();

  @override
  Future<void> saveSettings(NeuralSettings settings) async {}
}
