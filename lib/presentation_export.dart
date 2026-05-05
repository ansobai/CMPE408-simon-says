import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'main.dart';
import 'settings/neural_settings.dart';
import 'stats/stats_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _PresentationExportApp());
}

class _PresentationExportApp extends StatefulWidget {
  const _PresentationExportApp();

  @override
  State<_PresentationExportApp> createState() => _PresentationExportAppState();
}

class _PresentationExportAppState extends State<_PresentationExportApp> {
  final GlobalKey _captureKey = GlobalKey();
  late final List<GameSession> _sampleSessions = <GameSession>[
    GameSession(
      id: 'session-1',
      mode: GameModeKey.focus,
      startedAt: DateTime.utc(2026, 5, 3, 10, 00),
      endedAt: DateTime.utc(2026, 5, 3, 10, 02),
      score: 1840,
      bestStreak: 8,
      roundReached: 8,
      endReason: SessionEndReason.wrongTile,
    ),
    GameSession(
      id: 'session-2',
      mode: GameModeKey.overdrive,
      startedAt: DateTime.utc(2026, 5, 4, 12, 15),
      endedAt: DateTime.utc(2026, 5, 4, 12, 17),
      score: 3260,
      bestStreak: 11,
      roundReached: 11,
      endReason: SessionEndReason.timedOut,
    ),
  ];
  late final ValueNotifier<PlayerStats> _playerStats = ValueNotifier<PlayerStats>(
    PlayerStats.fromSessions(_sampleSessions),
  );
  late final ValueNotifier<List<GameSession>> _sessions =
      ValueNotifier<List<GameSession>>(<GameSession>[
        ..._sampleSessions,
      ]);
  final ValueNotifier<NeuralSettings> _settings = ValueNotifier<NeuralSettings>(
    const NeuralSettings(
      hapticsEnabled: true,
      reducedMotion: false,
      trainingHintsEnabled: true,
      confirmResetEnabled: true,
      appTheme: AppThemeProfile.neuralBlue,
    ),
  );

  late final List<_CaptureStep> _steps = <_CaptureStep>[
    _CaptureStep(
      fileName: '01_main_menu.png',
      warmup: const Duration(milliseconds: 300),
      builder: _buildMainMenu,
    ),
    _CaptureStep(
      fileName: '02_stats.png',
      warmup: const Duration(milliseconds: 300),
      builder: _buildStats,
    ),
    _CaptureStep(
      fileName: '03_settings.png',
      warmup: const Duration(milliseconds: 300),
      builder: _buildSettings,
    ),
    _CaptureStep(
      fileName: '04_focus_mode.png',
      warmup: const Duration(milliseconds: 2300),
      builder: _buildFocusGame,
    ),
    _CaptureStep(
      fileName: '05_overdrive_mode.png',
      warmup: const Duration(milliseconds: 1600),
      builder: _buildOverdriveGame,
    ),
  ];

  int _stepIndex = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_started) {
        _started = true;
        _runExport();
      }
    });
  }

  @override
  void dispose() {
    _playerStats.dispose();
    _sessions.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _CaptureStep step = _steps[_stepIndex];
    NeuralTheme.activate(_settings.value.appTheme);

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
      home: Scaffold(
        backgroundColor: NeuralTheme.background,
        body: Center(
          child: RepaintBoundary(
            key: _captureKey,
            child: SizedBox(
              width: 1080,
              height: 1920,
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(1080, 1920),
                  padding: EdgeInsets.only(top: 34, bottom: 24),
                ),
                child: step.builder(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainMenu() {
    return MainMenuScreen(
      playerStats: _playerStats,
      settings: _settings,
      onSessionCompleted: (_) async {},
      onOpenSettings: () {},
    );
  }

  Widget _buildStats() {
    return StatsScreen(
      playerStats: _playerStats,
      sessions: _sessions,
      settings: _settings,
    );
  }

  Widget _buildSettings() {
    return SettingsScreen(
      playerStats: _playerStats,
      settings: _settings,
      onSettingsChanged: (_) {},
    );
  }

  Widget _buildFocusGame() {
    return const GameScreen(
      mode: GameMode.focus,
      initialBestScore: 1840,
      settings: NeuralSettings(
        trainingHintsEnabled: true,
        appTheme: AppThemeProfile.neuralBlue,
      ),
      onSessionCompleted: _noopSessionSaver,
    );
  }

  Widget _buildOverdriveGame() {
    return const GameScreen(
      mode: GameMode.overdrive,
      initialBestScore: 3260,
      settings: NeuralSettings(
        trainingHintsEnabled: true,
        appTheme: AppThemeProfile.neuralBlue,
      ),
      onSessionCompleted: _noopSessionSaver,
    );
  }

  Future<void> _runExport() async {
    _resizeWindowForCapture();
    final Directory outputDir = Directory('presentation_assets');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    for (int index = 0; index < _steps.length; index++) {
      if (!mounted) {
        return;
      }
      setState(() {
        _stepIndex = index;
      });
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(_steps[index].warmup);
      await WidgetsBinding.instance.endOfFrame;
      await _saveCapture(File('${outputDir.path}\\${_steps[index].fileName}'));
    }

    exit(0);
  }

  void _resizeWindowForCapture() {
    if (!Platform.isWindows) {
      return;
    }

    final ffi.DynamicLibrary user32 = ffi.DynamicLibrary.open('user32.dll');
    final _GetForegroundWindow getForegroundWindow = user32.lookupFunction<
      _GetForegroundWindowNative,
      _GetForegroundWindow
    >('GetForegroundWindow');
    final _MoveWindow moveWindow = user32.lookupFunction<
      _MoveWindowNative,
      _MoveWindow
    >('MoveWindow');

    final ffi.Pointer<ffi.Void> windowHandle = getForegroundWindow();
    if (windowHandle == ffi.nullptr) {
      return;
    }

    moveWindow(windowHandle, 120, 80, 1080, 1920, 1);
  }

  Future<void> _saveCapture(File file) async {
    final RenderRepaintBoundary boundary =
        _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List pngBytes = byteData!.buffer.asUint8List();
    await file.writeAsBytes(pngBytes, flush: true);
  }
}

class _CaptureStep {
  const _CaptureStep({
    required this.fileName,
    required this.warmup,
    required this.builder,
  });

  final String fileName;
  final Duration warmup;
  final Widget Function() builder;
}

Future<void> _noopSessionSaver(GameSession _) async {}

typedef _GetForegroundWindowNative = ffi.Pointer<ffi.Void> Function();
typedef _GetForegroundWindow = ffi.Pointer<ffi.Void> Function();
typedef _MoveWindowNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void>,
      ffi.Int32,
      ffi.Int32,
      ffi.Int32,
      ffi.Int32,
      ffi.Int32,
    );
typedef _MoveWindow =
    int Function(ffi.Pointer<ffi.Void>, int, int, int, int, int);
