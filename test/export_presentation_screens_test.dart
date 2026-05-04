import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simon_says/main.dart';
import 'package:simon_says/settings/neural_settings.dart';
import 'package:simon_says/stats/stats_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('exports presentation screenshots', (WidgetTester tester) async {
    const Size captureSize = Size(1440, 2560);
    tester.view.physicalSize = captureSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final Directory outputDir = Directory('presentation_assets');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final ValueNotifier<PlayerStats> playerStats = ValueNotifier<PlayerStats>(
      PlayerStats.fromSessions(<GameSession>[
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
      ]),
    );
    final ValueNotifier<NeuralSettings> settings =
        ValueNotifier<NeuralSettings>(
          const NeuralSettings(
            hapticsEnabled: true,
            reducedMotion: false,
            trainingHintsEnabled: true,
            focusAssistEnabled: true,
            confirmResetEnabled: true,
            appTheme: AppThemeStyle.neon,
          ),
        );

    await _captureScreen(
      tester,
      name: '01_main_menu',
      child: MainMenuScreen(
        playerStats: playerStats,
        settings: settings,
        onSessionCompleted: (_) async {},
        onSettingsChanged: (_) {},
      ),
      outputDir: outputDir,
    );

    await _captureScreen(
      tester,
      name: '02_stats',
      child: StatsScreen(
        playerStats: playerStats,
        settings: settings,
        onSettingsChanged: (_) {},
      ),
      outputDir: outputDir,
    );

    await _captureScreen(
      tester,
      name: '03_settings',
      child: SettingsScreen(
        playerStats: playerStats,
        settings: settings,
        onSettingsChanged: (_) {},
      ),
      outputDir: outputDir,
    );

    await _captureScreen(
      tester,
      name: '04_focus_mode',
      child: const GameScreen(
        mode: GameMode.focus,
        initialBestStreak: 11,
        settings: NeuralSettings(
          trainingHintsEnabled: true,
          focusAssistEnabled: true,
          appTheme: AppThemeStyle.neon,
        ),
        onSessionCompleted: _noopSessionSaver,
      ),
      outputDir: outputDir,
      warmup: const Duration(milliseconds: 2300),
    );

    await _captureScreen(
      tester,
      name: '05_overdrive_mode',
      child: const GameScreen(
        mode: GameMode.overdrive,
        initialBestStreak: 11,
        settings: NeuralSettings(
          trainingHintsEnabled: true,
          focusAssistEnabled: true,
          appTheme: AppThemeStyle.neon,
        ),
        onSessionCompleted: _noopSessionSaver,
      ),
      outputDir: outputDir,
      warmup: const Duration(milliseconds: 1600),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    playerStats.dispose();
    settings.dispose();
  });
}

Future<void> _captureScreen(
  WidgetTester tester, {
  required String name,
  required Widget child,
  required Directory outputDir,
  Duration warmup = const Duration(milliseconds: 150),
}) async {
  final GlobalKey repaintKey = GlobalKey();
  await tester.pumpWidget(
    _buildPresentationApp(
      RepaintBoundary(
        key: repaintKey,
        child: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(warmup);

  final RenderRepaintBoundary boundary =
      repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? byteData = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  final Uint8List pngBytes = byteData!.buffer.asUint8List();
  final File file = File('${outputDir.path}${Platform.pathSeparator}$name.png');
  await file.writeAsBytes(pngBytes, flush: true);
}

Widget _buildPresentationApp(Widget home) {
  final NeuralVisualTheme visualTheme = NeuralTheme.visualThemeFor(
    AppThemeStyle.neon,
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: visualTheme.backgroundBase,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: visualTheme.primaryAccent,
        secondary: visualTheme.secondaryAccent,
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
    home: MediaQuery(
      data: const MediaQueryData(
        padding: EdgeInsets.only(top: 28, bottom: 20),
      ),
      child: home,
    ),
  );
}

Future<void> _noopSessionSaver(GameSession _) async {}
