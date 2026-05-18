import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simon_says/api/api_errors.dart';
import 'package:simon_says/auth/auth_models.dart';
import 'package:simon_says/auth/auth_repository.dart';
import 'package:simon_says/main.dart';
import 'package:simon_says/settings/neural_settings.dart';
import 'package:simon_says/settings/settings_repository.dart';
import 'package:simon_says/stats/stats_models.dart';
import 'package:simon_says/stats/stats_repository.dart';

const bool _generateCaptures = bool.fromEnvironment(
  'GENERATE_PRESENTATION_CAPTURES',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _mockAudioPlayersChannels();

  testWidgets(
    'captures current app states for the 5-minute presentation',
    (WidgetTester tester) async {
      await _setPhoneSurface(tester);

      final Directory outputDir = Directory(
        'presentation_assets/generated_5min',
      );
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      await _captureAuthStates(tester, outputDir);
      debugPrint('Captured auth states');
      await _captureSignedInFlow(tester, outputDir);
      debugPrint('Captured signed-in flow');
      await _captureGameplayStates(tester, outputDir);
      debugPrint('Captured gameplay states');
      await _captureEmptyState(tester, outputDir);
      debugPrint('Captured empty state');
      await _captureBackendWarning(tester, outputDir);
      debugPrint('Captured backend warning');
    },
    skip: !_generateCaptures,
  );
}

void _mockAudioPlayersChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (MethodCall call) async {
          switch (call.method) {
            case 'init':
            case 'dispose':
              return null;
            default:
              return 1;
          }
        },
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global/events'),
        (MethodCall call) async {
          return null;
        },
      );
}

Future<void> _setPhoneSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _captureAuthStates(WidgetTester tester, Directory outputDir) async {
  final _MutableAuthRepository authRepository = _MutableAuthRepository();

  await tester.pumpWidget(
    _CaptureFrame(
      child: NeuralRecallApp(
        authRepository: authRepository,
        statsRepository: const _EmptyStatsRepository(),
        settingsRepository: const _MemorySettingsRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await _capturePng(tester, outputDir, '01_auth_sign_in.png');

  await tester.tap(find.text('SIGN UP'));
  await tester.pumpAndSettle();
  await _capturePng(tester, outputDir, '02_auth_sign_up.png');

  await tester.enterText(find.byType(TextFormField).at(0), 'ab');
  await tester.enterText(find.byType(TextFormField).at(1), '12');
  await tester.tap(find.text('CREATE PROFILE'));
  await tester.pumpAndSettle();
  await _capturePng(tester, outputDir, '03_auth_invalid_input.png');
}

Future<void> _captureSignedInFlow(
  WidgetTester tester,
  Directory outputDir,
) async {
  final AppUser currentUser = AppUser(
    id: 2,
    username: 'bara',
    score: 3260,
    createdAt: DateTime.parse('2026-05-03T09:00:00Z'),
    updatedAt: DateTime.parse('2026-05-04T12:17:00Z'),
    lastPlayedAt: DateTime.parse('2026-05-04T12:17:00Z'),
  );
  final List<AppUser> leaderboardUsers = <AppUser>[
    AppUser(
      id: 1,
      username: 'pixel_ace',
      score: 3890,
      createdAt: DateTime.parse('2026-05-02T18:00:00Z'),
      updatedAt: DateTime.parse('2026-05-04T18:15:00Z'),
      lastPlayedAt: DateTime.parse('2026-05-04T18:15:00Z'),
    ),
    currentUser,
    AppUser(
      id: 3,
      username: 'lina',
      score: 2980,
      createdAt: DateTime.parse('2026-05-03T08:00:00Z'),
      updatedAt: DateTime.parse('2026-05-04T16:48:00Z'),
      lastPlayedAt: DateTime.parse('2026-05-04T16:48:00Z'),
    ),
  ];
  final List<GameSession> sessions = <GameSession>[
    GameSession(
      id: 'session-1',
      mode: GameModeKey.focus,
      startedAt: DateTime.parse('2026-05-04T10:00:00Z'),
      endedAt: DateTime.parse('2026-05-04T10:02:00Z'),
      score: 1840,
      bestStreak: 8,
      roundReached: 8,
      endReason: SessionEndReason.wrongTile,
    ),
    GameSession(
      id: 'session-2',
      mode: GameModeKey.overdrive,
      startedAt: DateTime.parse('2026-05-04T11:15:00Z'),
      endedAt: DateTime.parse('2026-05-04T11:17:00Z'),
      score: 3260,
      bestStreak: 11,
      roundReached: 11,
      endReason: SessionEndReason.timedOut,
    ),
    GameSession(
      id: 'session-3',
      mode: GameModeKey.focus,
      startedAt: DateTime.parse('2026-05-04T12:40:00Z'),
      endedAt: DateTime.parse('2026-05-04T12:42:00Z'),
      score: 2100,
      bestStreak: 9,
      roundReached: 9,
      endReason: SessionEndReason.wrongTile,
    ),
  ];
  final ValueNotifier<AppUser?> currentUserNotifier = ValueNotifier<AppUser?>(
    currentUser,
  );
  final ValueNotifier<PlayerStats> playerStatsNotifier =
      ValueNotifier<PlayerStats>(PlayerStats.fromSessions(sessions));
  final ValueNotifier<List<GameSession>> sessionsNotifier =
      ValueNotifier<List<GameSession>>(sessions);
  final ValueNotifier<List<AppUser>> leaderboardNotifier =
      ValueNotifier<List<AppUser>>(leaderboardUsers);
  final ValueNotifier<NeuralSettings> settingsNotifier =
      ValueNotifier<NeuralSettings>(
        const NeuralSettings(
          appTheme: AppThemeProfile.emberGlow,
          soundLevel: 0.7,
          overdriveWindowScale: 1.1,
        ),
      );

  await tester.pumpWidget(
    _CaptureFrame(
      child: _buildPresentationShell(
        MainMenuScreen(
          currentUser: currentUserNotifier,
          playerStats: playerStatsNotifier,
          settings: settingsNotifier,
          onSessionCompleted: _noopSaveSession,
          onOpenSettings: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await _capturePng(tester, outputDir, '04_main_menu.png');

  await tester.pumpWidget(
    _CaptureFrame(
      child: _buildPresentationShell(
        StatsScreen(
          currentUser: currentUserNotifier,
          playerStats: playerStatsNotifier,
          sessions: sessionsNotifier,
          leaderboardUsers: leaderboardNotifier,
          settings: settingsNotifier,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _capturePng(tester, outputDir, '05_stats_leaderboard.png');

  await tester.pumpWidget(
    _CaptureFrame(
      child: _buildPresentationShell(
        SettingsScreen(
          currentUser: currentUserNotifier,
          playerStats: playerStatsNotifier,
          settings: settingsNotifier,
          onSettingsChanged: (_) {},
          onSignOut: _noopSignOut,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _capturePng(tester, outputDir, '06_settings.png');
}

Future<void> _captureGameplayStates(
  WidgetTester tester,
  Directory outputDir,
) async {
  Future<void> pumpGame(GameMode mode) async {
    await tester.pumpWidget(
      _CaptureFrame(
        child: _buildPresentationShell(
          GameScreen(
            mode: mode,
            initialBestScore: mode == GameMode.focus ? 1840 : 3260,
            settings: const NeuralSettings(trainingHintsEnabled: true),
            onSessionCompleted: _noopSaveSession,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  {
    await pumpGame(GameMode.focus);
    await tester.pump(const Duration(milliseconds: 980));
    await _capturePng(tester, outputDir, '07_focus_mode.png');
    debugPrint('Captured focus mode');
  }

  {
    await pumpGame(GameMode.overdrive);
    await tester.pump(const Duration(milliseconds: 760));
    await _capturePng(tester, outputDir, '08_overdrive_mode.png');
    debugPrint('Captured overdrive mode');
  }

  {
    await pumpGame(GameMode.overdrive);
    await tester.pump(const Duration(milliseconds: 3400));
    await tester.pumpAndSettle();
    await _capturePng(tester, outputDir, '09_game_over.png');
    debugPrint('Captured game over');
  }
}

Future<void> _captureEmptyState(
  WidgetTester tester,
  Directory outputDir,
) async {
  final AppUser currentUser = AppUser(
    id: 1,
    username: 'bara',
    score: 0,
    createdAt: DateTime.parse('2026-05-04T10:00:00Z'),
    updatedAt: DateTime.parse('2026-05-04T10:00:00Z'),
  );
  final ValueNotifier<AppUser?> currentUserNotifier = ValueNotifier<AppUser?>(
    currentUser,
  );
  final ValueNotifier<PlayerStats> playerStatsNotifier =
      ValueNotifier<PlayerStats>(PlayerStats.empty());
  final ValueNotifier<List<GameSession>> sessionsNotifier =
      ValueNotifier<List<GameSession>>(const <GameSession>[]);
  final ValueNotifier<List<AppUser>> leaderboardNotifier =
      ValueNotifier<List<AppUser>>(const <AppUser>[]);
  final ValueNotifier<NeuralSettings> settingsNotifier =
      ValueNotifier<NeuralSettings>(const NeuralSettings());

  await tester.pumpWidget(
    _CaptureFrame(
      child: _buildPresentationShell(
        StatsScreen(
          currentUser: currentUserNotifier,
          playerStats: playerStatsNotifier,
          sessions: sessionsNotifier,
          leaderboardUsers: leaderboardNotifier,
          settings: settingsNotifier,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _capturePng(tester, outputDir, '10_no_data_state.png');
}

Future<void> _captureBackendWarning(
  WidgetTester tester,
  Directory outputDir,
) async {
  final AppUser currentUser = AppUser(
    id: 1,
    username: 'bara',
    score: 0,
    createdAt: DateTime.parse('2026-05-04T10:00:00Z'),
    updatedAt: DateTime.parse('2026-05-04T10:00:00Z'),
  );

  await tester.pumpWidget(
    _CaptureFrame(
      child: NeuralRecallApp(
        authRepository: _StaticAuthRepository(currentUser),
        statsRepository: const _ThrowingStatsRepository(),
        settingsRepository: const _MemorySettingsRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _capturePng(tester, outputDir, '11_backend_warning.png');
}

Future<void> _capturePng(
  WidgetTester tester,
  Directory outputDir,
  String fileName,
) async {
  final String goldenPath =
      '${outputDir.path.replaceAll('\\', '/')}/$fileName';
  await expectLater(
    find.byKey(const ValueKey<String>('presentation-capture')),
    matchesGoldenFile(goldenPath),
  );
}

class _CaptureFrame extends StatelessWidget {
  const _CaptureFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const ValueKey<String>('presentation-capture'),
      child: child,
    );
  }
}

Widget _buildPresentationShell(Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NeuralTheme.background,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: NeuralTheme.primary,
        secondary: NeuralTheme.secondary,
        surface: NeuralTheme.surface,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.6,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
        ),
      ),
    ),
    home: home,
  );
}

Future<void> _noopSaveSession(GameSession _) async {}

Future<void> _noopSignOut() async {}

class _MutableAuthRepository extends AuthRepository {
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

class _StaticAuthRepository extends AuthRepository {
  const _StaticAuthRepository(this.user);

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

class _ThrowingStatsRepository extends StatsRepository {
  const _ThrowingStatsRepository();

  @override
  Future<List<AppUser>> loadLeaderboardUsers({int? limit}) {
    throw const FormatException('corrupt leaderboard');
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

class _MemorySettingsRepository extends SettingsRepository {
  const _MemorySettingsRepository();

  @override
  Future<NeuralSettings> loadSettings() async => const NeuralSettings();

  @override
  Future<void> saveSettings(NeuralSettings settings) async {}
}
