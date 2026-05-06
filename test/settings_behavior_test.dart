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

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_rounded).hitTestable().first);
  await tester.pumpAndSettle();
}

Future<void> _returnToMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.grid_view_rounded).hitTestable().first);
  await tester.pumpAndSettle();
}

Future<void> _openFocusMode(WidgetTester tester) async {
  await tester.tap(find.text('Easy mode'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _disposeGameScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _toggleSetting(WidgetTester tester, String label) async {
  final Finder scrollable = find.byType(Scrollable).first;
  final Finder labelFinder = find.text(label);
  await tester.scrollUntilVisible(labelFinder, 300, scrollable: scrollable);
  await tester.pumpAndSettle();

  final Offset labelPosition = tester.getCenter(labelFinder);
  final Finder switchFinder = find.byType(Switch);
  for (
    int index = 0;
    index < tester.widgetList<Switch>(switchFinder).length;
    index++
  ) {
    final Finder candidate = switchFinder.at(index);
    final Offset switchPosition = tester.getCenter(candidate);
    if ((switchPosition.dy - labelPosition.dy).abs() < 80) {
      await tester.tap(candidate);
      await tester.pumpAndSettle();
      return;
    }
  }

  fail('Could not find switch for "$label".');
}

NeuralRecallApp _buildSignedInApp() {
  final AppUser user = AppUser(
    id: 1,
    username: 'bara',
    score: 0,
    createdAt: DateTime.parse('2026-05-04T10:00:00Z'),
    updatedAt: DateTime.parse('2026-05-04T10:00:00Z'),
  );
  return NeuralRecallApp(
    authRepository: _SignedInAuthRepository(user),
    statsRepository: const _NoopStatsRepository(),
    settingsRepository: const _InMemorySettingsRepository(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home screen renders mode cards', (WidgetTester tester) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(_buildSignedInApp());
    await tester.pumpAndSettle();

    expect(find.text('Easy mode'), findsOneWidget);
    expect(find.text('Hard Mode'), findsOneWidget);
    expect(find.text('V1.0.0'), findsOneWidget);
  });

  testWidgets('changing theme updates the active palette selection', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(_buildSignedInApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    await tester.scrollUntilVisible(
      find.text('Ember Glow'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ember Glow'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Current theme: Ember Glow'), findsOneWidget);

    await _returnToMenu(tester);
    await _openSettings(tester);

    expect(find.textContaining('Current theme: Ember Glow'), findsOneWidget);
  });

  testWidgets('training hints setting hides the gameplay hint card', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(_buildSignedInApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    await _toggleSetting(tester, 'Training Hints');
    await _returnToMenu(tester);
    await _openFocusMode(tester);

    expect(find.text('PATTERN BRIEF'), findsNothing);
    expect(find.text('FOCUS LOOP'), findsNothing);
    await _disposeGameScreen(tester);
  });

  testWidgets('confirm reset setting controls the reset dialog', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(_buildSignedInApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    await _toggleSetting(tester, 'Confirm Reset');
    await _returnToMenu(tester);
    await _openFocusMode(tester);

    await tester.tap(find.byIcon(Icons.restart_alt_rounded).first);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('RESET CURRENT RUN?'), findsNothing);
    await _disposeGameScreen(tester);
  });

  test('settings backend math changes real timing and sound values', () {
    const NeuralSettings muted = NeuralSettings(
      soundEnabled: false,
      soundLevel: 0.92,
    );
    expect(muted.effectiveSoundLevel, 0.0);

    const NeuralSettings faster = NeuralSettings(sequenceSpeed: 1.2);
    expect(
      faster.tuneDuration(const Duration(milliseconds: 1000)),
      const Duration(milliseconds: 833),
    );

    const NeuralSettings reduced = NeuralSettings(
      reducedMotion: true,
      sequenceSpeed: 0.9,
    );
    expect(
      reduced.tuneDuration(const Duration(milliseconds: 1000)),
      const Duration(milliseconds: 800),
    );

    const NeuralSettings forgiving = NeuralSettings(overdriveWindowScale: 1.2);
    expect(
      forgiving.tuneOverdriveWindow(
        const Duration(milliseconds: 1800),
        round: 3,
      ),
      const Duration(milliseconds: 2004),
    );
  });
}

class _SignedInAuthRepository extends AuthRepository {
  const _SignedInAuthRepository(this.user);

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

class _NoopStatsRepository extends StatsRepository {
  const _NoopStatsRepository();

  @override
  Future<List<AppUser>> loadLeaderboardUsers({int limit = 10}) async {
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

class _InMemorySettingsRepository extends SettingsRepository {
  const _InMemorySettingsRepository();

  @override
  Future<NeuralSettings> loadSettings() async => const NeuralSettings();

  @override
  Future<void> saveSettings(NeuralSettings _) async {}
}
