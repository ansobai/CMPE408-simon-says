import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'neural_sound_controller.dart';
import 'stats/local_stats_repository.dart';
import 'stats/stats_models.dart';
import 'stats/stats_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureFullscreenUi();
  runApp(const NeuralRecallApp());
}

class NeuralRecallApp extends StatefulWidget {
  const NeuralRecallApp({super.key, this.statsRepository});

  final StatsRepository? statsRepository;

  @override
  State<NeuralRecallApp> createState() => _NeuralRecallAppState();
}

class _NeuralRecallAppState extends State<NeuralRecallApp> {
  final ValueNotifier<PlayerStats> _playerStats = ValueNotifier<PlayerStats>(
    PlayerStats.empty(),
  );
  final ValueNotifier<NeuralSettings> _settings = ValueNotifier<NeuralSettings>(
    const NeuralSettings(),
  );
  late final StatsRepository _statsRepository;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _statsRepository = widget.statsRepository ?? LocalStatsRepository();
    WidgetsBinding.instance.addObserver(_fullscreenObserver);
    unawaited(_loadPersistedStats());
  }

  Future<void> _loadPersistedStats() async {
    PlayerStats stats = PlayerStats.empty();

    try {
      stats = await _statsRepository.loadStats();
    } catch (_) {
      stats = PlayerStats.empty();
    } finally {
      if (!mounted) {
        return;
      }

      _playerStats.value = stats;
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _saveCompletedSession(GameSession session) async {
    await _statsRepository.saveCompletedSession(session);
    final PlayerStats stats = await _statsRepository.loadStats();
    if (!mounted) {
      return;
    }

    _playerStats.value = stats;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_fullscreenObserver);
    _playerStats.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NeuralSettings>(
      valueListenable: _settings,
      builder: (context, currentSettings, _) {
        NeuralTheme.activate(currentSettings.appTheme);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: NeuralTheme.materialTheme,
          home: _isLoadingStats
              ? const _StartupLoadingScreen()
              : MainMenuScreen(
                  playerStats: _playerStats,
                  settings: _settings,
                  onSessionCompleted: _saveCompletedSession,
                ),
        );
      },
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeuralTheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: NeuralTheme.primary),
            SizedBox(height: 20),
            Text(
              'Loading neural profile...',
              style: TextStyle(color: NeuralTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

enum AppThemeProfile { neuralBlue, emberGlow, mintCircuit }

@immutable
class AppThemePalette {
  const AppThemePalette({
    required this.label,
    required this.primary,
    required this.primarySoft,
    required this.secondary,
    required this.secondarySoft,
    required this.tertiary,
    required this.primaryGlow,
    required this.secondaryGlow,
    required this.backgroundBottom,
    required this.onAccent,
  });

  final String label;
  final Color primary;
  final Color primarySoft;
  final Color secondary;
  final Color secondarySoft;
  final Color tertiary;
  final Color primaryGlow;
  final Color secondaryGlow;
  final Color backgroundBottom;
  final Color onAccent;
}

class NeuralTheme {
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF1C1B1B);
  static const Color surfaceHigh = Color(0xFF2A2A2A);
  static const Color surfaceHighest = Color(0xFF353534);
  static const Color outline = Color(0xFF3B494C);
  static const Color text = Color(0xFFE5E2E1);
  static const Color textMuted = Color(0xFFBAC9CC);
  static const Color textDim = Color(0xFF849396);
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);

  static const Map<AppThemeProfile, AppThemePalette> _palettes =
      <AppThemeProfile, AppThemePalette>{
        AppThemeProfile.neuralBlue: AppThemePalette(
          label: 'Neural Blue',
          primary: Color(0xFF00E5FF),
          primarySoft: Color(0xFFC3F5FF),
          secondary: Color(0xFF7C4DFF),
          secondarySoft: Color(0xFFCDBDFF),
          tertiary: Color(0xFFFEC931),
          primaryGlow: Color(0x3300E5FF),
          secondaryGlow: Color(0x267C4DFF),
          backgroundBottom: Color(0xFF0E0E0E),
          onAccent: Color(0xFF00363D),
        ),
        AppThemeProfile.emberGlow: AppThemePalette(
          label: 'Ember Glow',
          primary: Color(0xFFFF8A65),
          primarySoft: Color(0xFFFFD2C3),
          secondary: Color(0xFFFFC857),
          secondarySoft: Color(0xFFFFE4A5),
          tertiary: Color(0xFF7EE0C5),
          primaryGlow: Color(0x33FF8A65),
          secondaryGlow: Color(0x29FFC857),
          backgroundBottom: Color(0xFF120E0D),
          onAccent: Color(0xFF4A1906),
        ),
        AppThemeProfile.mintCircuit: AppThemePalette(
          label: 'Mint Circuit',
          primary: Color(0xFF5BF2C5),
          primarySoft: Color(0xFFD1FFF1),
          secondary: Color(0xFF4FC3F7),
          secondarySoft: Color(0xFFCBEFFF),
          tertiary: Color(0xFFFFB86C),
          primaryGlow: Color(0x305BF2C5),
          secondaryGlow: Color(0x264FC3F7),
          backgroundBottom: Color(0xFF0C1110),
          onAccent: Color(0xFF00382C),
        ),
      };

  static AppThemeProfile _activeProfile = AppThemeProfile.neuralBlue;

  static void activate(AppThemeProfile profile) {
    _activeProfile = profile;
  }

  static AppThemePalette paletteFor(AppThemeProfile profile) {
    return _palettes[profile]!;
  }

  static AppThemePalette get palette => _palettes[_activeProfile]!;

  static Color get primary => palette.primary;
  static Color get primarySoft => palette.primarySoft;
  static Color get secondary => palette.secondary;
  static Color get secondarySoft => palette.secondarySoft;
  static Color get tertiary => palette.tertiary;
  static Color get primaryGlow => palette.primaryGlow;
  static Color get secondaryGlow => palette.secondaryGlow;
  static Color get backgroundBottom => palette.backgroundBottom;
  static Color get onAccent => palette.onAccent;

  static ThemeData get materialTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surface,
        onPrimary: onAccent,
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
    );
  }
}

@immutable
class NeuralSettings {
  const NeuralSettings({
    this.hapticsEnabled = true,
    this.reducedMotion = false,
    this.trainingHintsEnabled = true,
    this.confirmResetEnabled = true,
    this.soundEnabled = true,
    this.soundLevel = 0.76,
    this.sequenceSpeed = 1.0,
    this.overdriveWindowScale = 1.0,
    this.appTheme = AppThemeProfile.neuralBlue,
  });

  final bool hapticsEnabled;
  final bool reducedMotion;
  final bool trainingHintsEnabled;
  final bool confirmResetEnabled;
  final bool soundEnabled;
  final double soundLevel;
  final double sequenceSpeed;
  final double overdriveWindowScale;
  final AppThemeProfile appTheme;

  NeuralSettings copyWith({
    bool? hapticsEnabled,
    bool? reducedMotion,
    bool? trainingHintsEnabled,
    bool? confirmResetEnabled,
    bool? soundEnabled,
    double? soundLevel,
    double? sequenceSpeed,
    double? overdriveWindowScale,
    AppThemeProfile? appTheme,
  }) {
    return NeuralSettings(
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      trainingHintsEnabled: trainingHintsEnabled ?? this.trainingHintsEnabled,
      confirmResetEnabled: confirmResetEnabled ?? this.confirmResetEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundLevel: soundLevel ?? this.soundLevel,
      sequenceSpeed: sequenceSpeed ?? this.sequenceSpeed,
      overdriveWindowScale: overdriveWindowScale ?? this.overdriveWindowScale,
      appTheme: appTheme ?? this.appTheme,
    );
  }

  Duration tuneDuration(
    Duration duration, {
    double reducedFactor = 0.72,
    int minMilliseconds = 60,
  }) {
    if (!reducedMotion) {
      final int adjustedMs = math.max(
        minMilliseconds,
        (duration.inMilliseconds / sequenceSpeed).round(),
      );
      return Duration(milliseconds: adjustedMs);
    }

    final int scaledMs = math.max(
      minMilliseconds,
      ((duration.inMilliseconds * reducedFactor) / sequenceSpeed).round(),
    );
    return Duration(milliseconds: scaledMs);
  }

  Duration tuneOverdriveWindow(
    Duration baseTapTimeout, {
    required int round,
    int decayPerRound = 65,
    int minMilliseconds = 700,
  }) {
    final int adjustedMs = math.max(
      minMilliseconds,
      baseTapTimeout.inMilliseconds - math.max(0, round - 1) * decayPerRound,
    );
    return Duration(milliseconds: (adjustedMs * overdriveWindowScale).round());
  }

  double get effectiveSoundLevel =>
      soundEnabled ? soundLevel.clamp(0.0, 1.0) : 0.0;

  String get paceLabel {
    if (sequenceSpeed < 0.95) {
      return 'Steady';
    }
    if (sequenceSpeed > 1.08) {
      return 'Fast';
    }
    return 'Balanced';
  }

  String get overdriveLabel {
    if (overdriveWindowScale < 0.95) {
      return 'Tight';
    }
    if (overdriveWindowScale > 1.08) {
      return 'Forgiving';
    }
    return 'Standard';
  }
}

const double _navBarBaseHeight = 88;
const double _mainMenuDesignWidth = 560;
const double _mainMenuDesignHeight = 680;
const double _statsScreenDesignWidth = 560;
const double _gameScreenDesignWidth = 560;
const double _gameScreenDesignHeight = 760;

final _FullscreenUiObserver _fullscreenObserver = _FullscreenUiObserver();

Future<void> _configureFullscreenUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
}

class _FullscreenUiObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _configureFullscreenUi();
    }
  }
}

enum GameMode {
  focus(
    label: 'Focus Mode',
    menuTitle: 'Easy mode',
    subtitle: '4 Tiles | Relaxed Speed',
    scoreLabel: 'FOCUS MODE',
    gridSize: 2,
    icon: Icons.auto_awesome_motion_rounded,
    flashDuration: Duration(milliseconds: 560),
    flashGap: Duration(milliseconds: 180),
    roundLeadIn: Duration(milliseconds: 420),
    pointsPerStep: 140,
    roundBonus: 120,
  ),
  overdrive(
    label: 'Overdrive Mode',
    menuTitle: 'Hard Mode',
    subtitle: '9 Tiles | Rapid Sequence',
    scoreLabel: 'OVERDRIVE',
    gridSize: 3,
    icon: Icons.bolt_rounded,
    flashDuration: Duration(milliseconds: 300),
    flashGap: Duration(milliseconds: 90),
    roundLeadIn: Duration(milliseconds: 240),
    pointsPerStep: 260,
    roundBonus: 220,
    baseTapTimeout: Duration(milliseconds: 1800),
  );

  const GameMode({
    required this.label,
    required this.menuTitle,
    required this.subtitle,
    required this.scoreLabel,
    required this.gridSize,
    required this.icon,
    required this.flashDuration,
    required this.flashGap,
    required this.roundLeadIn,
    required this.pointsPerStep,
    required this.roundBonus,
    this.baseTapTimeout,
  });

  final String label;
  final String menuTitle;
  final String subtitle;
  final String scoreLabel;
  final int gridSize;
  final IconData icon;
  final Duration flashDuration;
  final Duration flashGap;
  final Duration roundLeadIn;
  final int pointsPerStep;
  final int roundBonus;
  final Duration? baseTapTimeout;

  Color get accent =>
      this == GameMode.focus ? NeuralTheme.primary : NeuralTheme.secondary;
}

enum GamePhase { booting, showing, input, roundClear, failed }

extension on GameMode {
  GameModeKey get statsKey {
    switch (this) {
      case GameMode.focus:
        return GameModeKey.focus;
      case GameMode.overdrive:
        return GameModeKey.overdrive;
    }
  }
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({
    super.key,
    required this.playerStats,
    required this.settings,
    required this.onSessionCompleted,
  });

  final ValueNotifier<PlayerStats> playerStats;
  final ValueNotifier<NeuralSettings> settings;
  final Future<void> Function(GameSession session) onSessionCompleted;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double bottomNavHeight = 74 + math.max(12, bottomInset);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF131313), Color(0xFF0E0E0E)],
          ),
        ),
        child: Stack(
          children: [
            const _BackgroundEffects(),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  NeuralTopBar(onAction: () => _openSettings(context)),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 8, 24, bottomNavHeight),
                      child: _ScaleToFit(
                        designWidth: _mainMenuDesignWidth,
                        designHeight: _mainMenuDesignHeight,
                        child: Column(
                          children: [
                            const _HeroLogo(),
                            const SizedBox(height: 28),
                            _ModeButton(
                              mode: GameMode.focus,
                              onTap: () => _openGame(context, GameMode.focus),
                            ),
                            const SizedBox(height: 16),
                            _ModeButton(
                              mode: GameMode.overdrive,
                              onTap: () =>
                                  _openGame(context, GameMode.overdrive),
                            ),
                            const Spacer(),
                            Text(
                              'V1.0.0',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: NeuralTheme.textDim.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: NeuralBottomNav(
                selected: NeuralNavItem.grid,
                onItemSelected: (item) => _handleNavigation(context, item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGame(BuildContext context, GameMode mode) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          mode: mode,
          initialBestStreak: playerStats.value.bestStreak,
          settings: settings.value,
          onSessionCompleted: onSessionCompleted,
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SettingsScreen(playerStats: playerStats, settings: settings),
      ),
    );
  }

  Future<void> _openStats(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StatsScreen(playerStats: playerStats, settings: settings),
      ),
    );
  }

  void _handleNavigation(BuildContext context, NeuralNavItem item) {
    if (item == NeuralNavItem.stats) {
      _openStats(context);
      return;
    }

    if (item == NeuralNavItem.settings) {
      _openSettings(context);
    }
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({
    super.key,
    required this.playerStats,
    required this.settings,
  });

  final ValueNotifier<PlayerStats> playerStats;
  final ValueNotifier<NeuralSettings> settings;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double bottomNavHeight = _navBarBaseHeight + bottomInset;
    return ValueListenableBuilder<NeuralSettings>(
      valueListenable: settings,
      builder: (context, currentSettings, _) {
        NeuralTheme.activate(currentSettings.appTheme);
        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(color: NeuralTheme.background),
            child: Stack(
              children: [
                const _BackgroundEffects(),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      NeuralTopBar(onBack: () => Navigator.of(context).pop()),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            8,
                            24,
                            bottomNavHeight + 18,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: _statsScreenDesignWidth,
                              ),
                              child: ValueListenableBuilder<PlayerStats>(
                                valueListenable: playerStats,
                                builder: (context, stats, _) {
                                  return _StatsDashboard(stats: stats);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: NeuralBottomNav(
                    selected: NeuralNavItem.stats,
                    onItemSelected: (item) {
                      if (item == NeuralNavItem.grid) {
                        Navigator.of(context).pop();
                      }
                      if (item == NeuralNavItem.settings) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => SettingsScreen(
                              playerStats: playerStats,
                              settings: settings,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.playerStats,
    required this.settings,
  });

  final ValueNotifier<PlayerStats> playerStats;
  final ValueNotifier<NeuralSettings> settings;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double bottomNavHeight = _navBarBaseHeight + bottomInset;
    return ValueListenableBuilder<NeuralSettings>(
      valueListenable: settings,
      builder: (context, currentSettings, _) {
        NeuralTheme.activate(currentSettings.appTheme);
        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(color: NeuralTheme.background),
            child: Stack(
              children: [
                const _BackgroundEffects(),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      NeuralTopBar(onBack: () => Navigator.of(context).pop()),
                      Expanded(
                        child: ValueListenableBuilder<PlayerStats>(
                          valueListenable: playerStats,
                          builder: (context, currentStats, child) {
                            return SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                24,
                                8,
                                24,
                                bottomNavHeight + 18,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: _statsScreenDesignWidth,
                                  ),
                                  child: _SettingsDashboard(
                                    bestStreak: currentStats.bestStreak,
                                    settings: currentSettings,
                                    onSettingsChanged: (nextSettings) {
                                      settings.value = nextSettings;
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: NeuralBottomNav(
                    selected: NeuralNavItem.settings,
                    onItemSelected: (item) {
                      if (item == NeuralNavItem.grid) {
                        Navigator.of(context).pop();
                      }
                      if (item == NeuralNavItem.stats) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => StatsScreen(
                              playerStats: playerStats,
                              settings: settings,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsDashboard extends StatelessWidget {
  const _SettingsDashboard({
    required this.bestStreak,
    required this.settings,
    required this.onSettingsChanged,
  });

  final int bestStreak;
  final NeuralSettings settings;
  final ValueChanged<NeuralSettings> onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'APP SETTINGS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: NeuralTheme.textDim.withValues(alpha: 0.52),
          ),
        ),
        const SizedBox(height: 18),
        _SettingsHeroCard(bestStreak: bestStreak, settings: settings),
        const SizedBox(height: 22),
        const _SettingsSectionTitle(
          label: 'APPEARANCE',
          subtitle: 'Pick the app palette and visual intensity.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AppThemeProfile.values.map((themeProfile) {
            final AppThemePalette palette = NeuralTheme.paletteFor(
              themeProfile,
            );
            return _ThemeProfileCard(
              profile: themeProfile,
              palette: palette,
              selected: settings.appTheme == themeProfile,
              onTap: () {
                onSettingsChanged(settings.copyWith(appTheme: themeProfile));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        _SettingsToggleCard(
          icon: Icons.motion_photos_off_rounded,
          title: 'Reduced Motion',
          description:
              'Shortens flashes and transitions for a calmer, snappier board.',
          value: settings.reducedMotion,
          accent: NeuralTheme.secondarySoft,
          onChanged: (enabled) {
            onSettingsChanged(settings.copyWith(reducedMotion: enabled));
          },
        ),
        const SizedBox(height: 24),
        const _SettingsSectionTitle(
          label: 'GAMEPLAY',
          subtitle: 'Change timing and helper behavior inside active runs.',
        ),
        const SizedBox(height: 14),
        _SettingsSliderCard(
          icon: Icons.speed_rounded,
          title: 'Sequence Pace',
          description:
              'Controls how fast flashes and round transitions feel across both modes.',
          value: settings.sequenceSpeed,
          min: 0.85,
          max: 1.20,
          divisions: 7,
          accent: NeuralTheme.primary,
          valueLabel:
              '${settings.paceLabel} ${_percent(settings.sequenceSpeed)}',
          onChanged: (value) {
            onSettingsChanged(settings.copyWith(sequenceSpeed: value));
          },
        ),
        const SizedBox(height: 14),
        _SettingsSliderCard(
          icon: Icons.timer_outlined,
          title: 'Overdrive Reaction Window',
          description:
              'Widens or tightens the tap timer only for overdrive rounds.',
          value: settings.overdriveWindowScale,
          min: 0.85,
          max: 1.25,
          divisions: 8,
          accent: NeuralTheme.secondary,
          valueLabel:
              '${settings.overdriveLabel} ${_percent(settings.overdriveWindowScale)}',
          onChanged: (value) {
            onSettingsChanged(settings.copyWith(overdriveWindowScale: value));
          },
        ),
        const SizedBox(height: 14),
        _SettingsToggleCard(
          icon: Icons.tips_and_updates_rounded,
          title: 'Training Hints',
          description:
              'Keeps the live hint card visible under the board while you play.',
          value: settings.trainingHintsEnabled,
          accent: NeuralTheme.primary,
          onChanged: (enabled) {
            onSettingsChanged(settings.copyWith(trainingHintsEnabled: enabled));
          },
        ),
        const SizedBox(height: 14),
        _SettingsToggleCard(
          icon: Icons.restart_alt_rounded,
          title: 'Confirm Reset',
          description:
              'Requires confirmation before wiping the current run from the game screen.',
          value: settings.confirmResetEnabled,
          accent: NeuralTheme.tertiary,
          onChanged: (enabled) {
            onSettingsChanged(settings.copyWith(confirmResetEnabled: enabled));
          },
        ),
        const SizedBox(height: 24),
        const _SettingsSectionTitle(
          label: 'FEEDBACK',
          subtitle: 'Tune what you hear and feel when the board responds.',
        ),
        const SizedBox(height: 14),
        _SettingsToggleCard(
          icon: Icons.graphic_eq_rounded,
          title: 'Sound Effects',
          description:
              'Plays the round sequence tones and tap confirmations during the run.',
          value: settings.soundEnabled,
          accent: NeuralTheme.primarySoft,
          onChanged: (enabled) {
            onSettingsChanged(settings.copyWith(soundEnabled: enabled));
          },
        ),
        const SizedBox(height: 14),
        _SettingsSliderCard(
          icon: Icons.volume_up_rounded,
          title: 'Sound Intensity',
          description:
              'Sets the loudness of the game effects without touching your phone volume.',
          value: settings.soundLevel,
          min: 0.20,
          max: 1.00,
          divisions: 8,
          accent: NeuralTheme.tertiary,
          enabled: settings.soundEnabled,
          valueLabel: '${(settings.soundLevel * 100).round()}%',
          onChanged: (value) {
            onSettingsChanged(settings.copyWith(soundLevel: value));
          },
        ),
        const SizedBox(height: 14),
        _SettingsToggleCard(
          icon: Icons.vibration_rounded,
          title: 'Haptic Feedback',
          description:
              'Adds tactile pulses for sequence playback, taps, and mistakes.',
          value: settings.hapticsEnabled,
          accent: NeuralTheme.primarySoft,
          onChanged: (enabled) {
            onSettingsChanged(settings.copyWith(hapticsEnabled: enabled));
          },
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: NeuralTheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: NeuralTheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            'Everything here applies immediately. Theme changes repaint the app, gameplay settings affect new rounds, and feedback changes are ready for your next tap.',
            style: const TextStyle(
              color: NeuralTheme.textMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsHeroCard extends StatelessWidget {
  const _SettingsHeroCard({required this.bestStreak, required this.settings});

  final int bestStreak;
  final NeuralSettings settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NeuralTheme.primary.withValues(alpha: 0.18),
            NeuralTheme.surface,
          ],
        ),
        border: Border.all(color: NeuralTheme.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: NeuralTheme.primaryGlow.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: NeuralTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: NeuralTheme.primary,
                  size: 34,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTROL DECK',
                      style: TextStyle(
                        color: NeuralTheme.primarySoft,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Best streak: $bestStreak. Current theme: ${NeuralTheme.palette.label}. Pace: ${settings.paceLabel}.',
                      style: const TextStyle(
                        color: NeuralTheme.textMuted,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _SettingsStatChip(
                  label: 'BEST CHAIN',
                  value: '$bestStreak',
                  accent: NeuralTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SettingsStatChip(
                  label: 'SFX',
                  value: settings.soundEnabled
                      ? '${(settings.soundLevel * 100).round()}%'
                      : 'OFF',
                  accent: NeuralTheme.secondarySoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SettingsStatChip(
                  label: 'OVERDRIVE',
                  value: settings.overdriveLabel,
                  accent: NeuralTheme.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _percent(double value) => '${(value * 100).round()}%';

class _SettingsStatChip extends StatelessWidget {
  const _SettingsStatChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: NeuralTheme.textDim),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeProfileCard extends StatelessWidget {
  const _ThemeProfileCard({
    required this.profile,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppThemeProfile profile;
  final AppThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NeuralTheme.surface.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? palette.primary.withValues(alpha: 0.65)
                    : NeuralTheme.outline.withValues(alpha: 0.24),
                width: selected ? 1.6 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: palette.primaryGlow.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ThemeDot(color: palette.primary),
                    const SizedBox(width: 8),
                    _ThemeDot(color: palette.secondary),
                    const SizedBox(width: 8),
                    _ThemeDot(color: palette.tertiary),
                    const Spacer(),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: palette.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  palette.label,
                  style: TextStyle(
                    color: selected ? palette.primarySoft : NeuralTheme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  switch (profile) {
                    AppThemeProfile.neuralBlue => 'Classic cyber glow',
                    AppThemeProfile.emberGlow => 'Warm neon contrast',
                    AppThemeProfile.mintCircuit => 'Cool arcade pulse',
                  },
                  style: const TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeDot extends StatelessWidget {
  const _ThemeDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({required this.label, required this.subtitle});

  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: NeuralTheme.textDim.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: NeuralTheme.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _SettingsToggleCard extends StatelessWidget {
  const _SettingsToggleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconPlate(icon: icon, color: accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NeuralTheme.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: accent,
            activeTrackColor: accent.withValues(alpha: 0.35),
            inactiveThumbColor: NeuralTheme.textMuted,
            inactiveTrackColor: NeuralTheme.surfaceHighest,
          ),
        ],
      ),
    );
  }
}

class _SettingsSliderCard extends StatelessWidget {
  const _SettingsSliderCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.accent,
    required this.valueLabel,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color accent;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color cardAccent = enabled
        ? accent
        : NeuralTheme.textDim.withValues(alpha: 0.55);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardAccent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconPlate(icon: icon, color: cardAccent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled
                            ? NeuralTheme.text
                            : NeuralTheme.textMuted.withValues(alpha: 0.75),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: enabled
                            ? NeuralTheme.textMuted
                            : NeuralTheme.textDim,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cardAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  valueLabel,
                  style: TextStyle(
                    color: cardAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: cardAccent,
              inactiveTrackColor: NeuralTheme.surfaceHighest,
              thumbColor: cardAccent,
              overlayColor: cardAccent.withValues(alpha: 0.12),
              valueIndicatorColor: cardAccent,
              disabledActiveTrackColor: NeuralTheme.textDim.withValues(
                alpha: 0.22,
              ),
              disabledInactiveTrackColor: NeuralTheme.surfaceHighest,
              disabledThumbColor: NeuralTheme.textDim,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsDashboard extends StatelessWidget {
  const _StatsDashboard({required this.stats});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PERFORMANCE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: NeuralTheme.textDim.withValues(alpha: 0.52),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Local training record from completed sessions saved on this device.',
          style: TextStyle(
            color: NeuralTheme.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        _BestStreakCard(bestStreak: stats.bestStreak),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isTwoColumn = constraints.maxWidth >= 430;
            final double cardWidth = isTwoColumn
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: 'BEST SCORE',
                    value: _formatNumber(stats.bestScore),
                    accent: NeuralTheme.secondary,
                    icon: Icons.emoji_events_rounded,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: 'TOTAL SESSIONS',
                    value: _formatNumber(stats.totalSessions),
                    accent: NeuralTheme.primary,
                    icon: Icons.layers_rounded,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: 'AVERAGE SCORE',
                    value: _formatAverage(stats.averageScore),
                    accent: NeuralTheme.primarySoft,
                    icon: Icons.bar_chart_rounded,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: 'AVERAGE ROUNDS',
                    value: _formatAverage(stats.averageRoundsReached),
                    accent: NeuralTheme.tertiary,
                    icon: Icons.route_rounded,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: 'FOCUS BEST',
                    value: _formatNumber(
                      stats.bestScoreByMode[GameModeKey.focus] ?? 0,
                    ),
                    accent: NeuralTheme.primary,
                    icon: Icons.auto_awesome_motion_rounded,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: 'OVERDRIVE BEST',
                    value: _formatNumber(
                      stats.bestScoreByMode[GameModeKey.overdrive] ?? 0,
                    ),
                    accent: NeuralTheme.secondarySoft,
                    icon: Icons.bolt_rounded,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: 'LAST PLAYED',
                    value: _formatDate(stats.lastPlayedAt),
                    accent: NeuralTheme.primarySoft,
                    icon: Icons.event_rounded,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconPlate(icon: icon, color: accent),
          const SizedBox(height: 16),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: NeuralTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.mode,
    required this.initialBestStreak,
    required this.settings,
    required this.onSessionCompleted,
  });

  final GameMode mode;
  final int initialBestStreak;
  final NeuralSettings settings;
  final Future<void> Function(GameSession session) onSessionCompleted;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final math.Random _random;
  late final int _tileCount;
  late final NeuralSoundController _soundController;
  final List<int> _sequence = <int>[];
  Timer? _inputTimer;
  int _sessionId = 0;
  int? _highlightedTile;
  int? _pressedTile;
  int? _errorTile;
  int _score = 0;
  int _streak = 0;
  int _bestRun = 0;
  int _round = 0;
  int _inputIndex = 0;
  double _sequenceProgress = 0;
  double _timerProgress = 1;
  GamePhase _phase = GamePhase.booting;
  bool _isSubmitting = false;
  bool _didRecordCurrentSession = false;
  DateTime? _sessionStartedAt;

  @override
  void initState() {
    super.initState();
    _random = math.Random();
    _tileCount = widget.mode.gridSize * widget.mode.gridSize;
    _soundController = NeuralSoundController();
    unawaited(_soundController.warmUp());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startNewGame());
    });
  }

  int _nextTile(int current) {
    if (_tileCount == 1) {
      return current;
    }
    int next = _random.nextInt(_tileCount);
    while (next == current) {
      next = _random.nextInt(_tileCount);
    }
    return next;
  }

  Future<void> _startNewGame() async {
    final int session = ++_sessionId;
    final DateTime startedAt = DateTime.now();
    _cancelInputTimer();
    if (mounted) {
      setState(() {
        _sequence.clear();
        _highlightedTile = null;
        _pressedTile = null;
        _errorTile = null;
        _score = 0;
        _streak = 0;
        _bestRun = 0;
        _round = 0;
        _inputIndex = 0;
        _sequenceProgress = 0;
        _timerProgress = 1;
        _phase = GamePhase.booting;
      });
    }
    _didRecordCurrentSession = false;
    _sessionStartedAt = startedAt;

    await Future<void>.delayed(
      widget.settings.tuneDuration(
        const Duration(milliseconds: 320),
        reducedFactor: 0.75,
        minMilliseconds: 160,
      ),
    );
    if (!_sessionIsActive(session)) {
      return;
    }
    await _startNextRound(session);
  }

  Future<void> _startNextRound(int session) async {
    if (!_sessionIsActive(session)) {
      return;
    }

    final int nextTile = _sequence.isEmpty
        ? _random.nextInt(_tileCount)
        : _nextTile(_sequence.last);

    setState(() {
      _sequence.add(nextTile);
      _round = _sequence.length;
      _inputIndex = 0;
      _sequenceProgress = 0;
      _timerProgress = 1;
      _highlightedTile = null;
      _pressedTile = null;
      _errorTile = null;
      _phase = GamePhase.showing;
    });

    await Future<void>.delayed(_roundLeadInDuration);
    if (!_sessionIsActive(session)) {
      return;
    }

    await _playSequence(session);
    if (!_sessionIsActive(session)) {
      return;
    }
    _beginInput(session);
  }

  Future<void> _playSequence(int session) async {
    for (int index = 0; index < _sequence.length; index++) {
      if (!_sessionIsActive(session)) {
        return;
      }

      setState(() {
        _highlightedTile = _sequence[index];
        _pressedTile = null;
        _errorTile = null;
        _sequenceProgress = index / _sequence.length;
      });
      _playSequenceHaptic();
      unawaited(
        _soundController.playSequenceStep(
          streak: _streak,
          enabled: widget.settings.soundEnabled,
          masterVolume: widget.settings.effectiveSoundLevel,
        ),
      );

      await Future<void>.delayed(_flashDuration);
      if (!_sessionIsActive(session)) {
        return;
      }

      setState(() {
        _highlightedTile = null;
        _sequenceProgress = (index + 1) / _sequence.length;
      });

      await Future<void>.delayed(_flashGapDuration);
    }
  }

  void _beginInput(int session) {
    if (!_sessionIsActive(session)) {
      return;
    }

    setState(() {
      _phase = GamePhase.input;
      _sequenceProgress = 0;
      _timerProgress = 1;
    });
    _armInputTimer(session);
  }

  Duration? _inputWindowForCurrentTurn() {
    final Duration? baseTapTimeout = widget.mode.baseTapTimeout;
    if (baseTapTimeout == null) {
      return null;
    }
    return widget.settings.tuneOverdriveWindow(baseTapTimeout, round: _round);
  }

  void _armInputTimer(int session) {
    _cancelInputTimer();
    final Duration? inputWindow = _inputWindowForCurrentTurn();
    if (inputWindow == null) {
      return;
    }

    final DateTime deadline = DateTime.now().add(inputWindow);
    _inputTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_sessionIsActive(session) || _phase != GamePhase.input) {
        timer.cancel();
        return;
      }

      final int remainingMs = deadline
          .difference(DateTime.now())
          .inMilliseconds;
      if (remainingMs <= 0) {
        timer.cancel();
        if (!mounted || session != _sessionId) {
          return;
        }

        setState(() {
          _timerProgress = 0;
        });
        unawaited(
          _handleFailure(
            summary: 'Time expired',
            endReason: SessionEndReason.timedOut,
          ),
        );
        return;
      }

      if (mounted && session == _sessionId) {
        setState(() {
          _timerProgress = (remainingMs / inputWindow.inMilliseconds).clamp(
            0.0,
            1.0,
          );
        });
      }
    });
  }

  Future<void> _handleTileTap(int index) async {
    if (_isSubmitting || _phase != GamePhase.input) {
      return;
    }

    final int session = _sessionId;
    final int expectedTile = _sequence[_inputIndex];
    final bool isCorrectTile = index == expectedTile;
    final bool completesRound =
        isCorrectTile && _inputIndex + 1 >= _sequence.length;
    _cancelInputTimer();

    setState(() {
      _pressedTile = index;
      _errorTile = null;
    });
    _playTapHaptic();
    unawaited(
      _soundController.playTap(
        streak: _streak + (isCorrectTile ? 1 : 0),
        completedRound: completesRound,
        enabled: widget.settings.soundEnabled,
        masterVolume: widget.settings.effectiveSoundLevel,
      ),
    );

    await Future<void>.delayed(
      widget.settings.tuneDuration(
        Duration(milliseconds: widget.mode == GameMode.focus ? 150 : 100),
        reducedFactor: 0.72,
        minMilliseconds: 70,
      ),
    );
    if (!_sessionIsActive(session) || _phase != GamePhase.input) {
      return;
    }

    if (index != expectedTile) {
      setState(() {
        _pressedTile = null;
        _errorTile = index;
      });
      _playFailureHaptic();
      await Future<void>.delayed(
        widget.settings.tuneDuration(
          const Duration(milliseconds: 180),
          reducedFactor: 0.72,
          minMilliseconds: 90,
        ),
      );
      if (_sessionIsActive(session)) {
        await _handleFailure(
          summary: 'Wrong tile',
          endReason: SessionEndReason.wrongTile,
          errorTile: index,
        );
      }
      return;
    }

    final int nextInputIndex = _inputIndex + 1;
    final bool completedRound = nextInputIndex >= _sequence.length;

    setState(() {
      _pressedTile = null;
      _highlightedTile = expectedTile;
      _inputIndex = nextInputIndex;
      _sequenceProgress = nextInputIndex / _sequence.length;
      _score += widget.mode.pointsPerStep;
      _streak += 1;
      _bestRun = math.max(_bestRun, _streak);
      if (completedRound) {
        _score += widget.mode.roundBonus;
        _phase = GamePhase.roundClear;
        _timerProgress = 1;
      }
    });
    _playSuccessHaptic(completedRound: completedRound);

    await Future<void>.delayed(
      widget.settings.tuneDuration(
        const Duration(milliseconds: 140),
        reducedFactor: 0.7,
        minMilliseconds: 70,
      ),
    );
    if (!_sessionIsActive(session)) {
      return;
    }

    setState(() {
      _highlightedTile = null;
    });

    if (completedRound) {
      await Future<void>.delayed(_roundLeadInDuration);
      if (_sessionIsActive(session)) {
        await _startNextRound(session);
      }
      return;
    }

    _armInputTimer(session);
  }

  Future<void> _handleFailure({
    required String summary,
    required SessionEndReason endReason,
    int? errorTile,
  }) async {
    if (_isSubmitting || _didRecordCurrentSession) {
      return;
    }

    _isSubmitting = true;
    _didRecordCurrentSession = true;
    _cancelInputTimer();
    setState(() {
      _phase = GamePhase.failed;
      _highlightedTile = null;
      _pressedTile = null;
      _errorTile = errorTile;
      _sequenceProgress = 1;
      _timerProgress = 0;
    });

    final DateTime endedAt = DateTime.now();
    final GameSession completedSession = GameSession(
      id: '${widget.mode.statsKey.name}-${endedAt.microsecondsSinceEpoch}',
      mode: widget.mode.statsKey,
      startedAt: _sessionStartedAt ?? endedAt,
      endedAt: endedAt,
      score: _score,
      bestStreak: _bestRun,
      roundReached: _round,
      endReason: endReason,
    );

    final bool restart =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => GameOverDialog(
            mode: widget.mode,
            score: _score,
            bestRun: _bestRun,
            roundReached: _round,
            summary: summary,
            newHighScore: _bestRun > widget.initialBestStreak,
          ),
        ) ??
        false;

    try {
      await widget.onSessionCompleted(completedSession);
    } finally {
      _isSubmitting = false;
    }

    if (!mounted) {
      return;
    }
    if (restart) {
      unawaited(_startNewGame());
    } else {
      Navigator.of(context).pop();
    }
  }

  Duration get _flashDuration => widget.settings.tuneDuration(
    widget.mode.flashDuration,
    reducedFactor: 0.68,
    minMilliseconds: 110,
  );

  Duration get _flashGapDuration => widget.settings.tuneDuration(
    widget.mode.flashGap,
    reducedFactor: 0.68,
    minMilliseconds: 50,
  );

  Duration get _roundLeadInDuration => widget.settings.tuneDuration(
    widget.mode.roundLeadIn,
    reducedFactor: 0.72,
    minMilliseconds: 140,
  );

  void _playSequenceHaptic() {
    if (!widget.settings.hapticsEnabled) {
      return;
    }
    unawaited(HapticFeedback.selectionClick());
  }

  void _playTapHaptic() {
    if (!widget.settings.hapticsEnabled) {
      return;
    }
    unawaited(HapticFeedback.lightImpact());
  }

  void _playSuccessHaptic({required bool completedRound}) {
    if (!widget.settings.hapticsEnabled) {
      return;
    }
    unawaited(
      completedRound
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.selectionClick(),
    );
  }

  void _playFailureHaptic() {
    if (!widget.settings.hapticsEnabled) {
      return;
    }
    unawaited(HapticFeedback.heavyImpact());
  }

  bool _sessionIsActive(int session) {
    return mounted && session == _sessionId && !_isSubmitting;
  }

  void _cancelInputTimer() {
    _inputTimer?.cancel();
    _inputTimer = null;
  }

  Future<void> _resetGame() async {
    if (widget.settings.confirmResetEnabled) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _ResetConfirmDialog(),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    unawaited(_startNewGame());
  }

  String get _phaseLabel {
    switch (_phase) {
      case GamePhase.booting:
        return 'INITIALIZING';
      case GamePhase.showing:
        return 'WATCH';
      case GamePhase.input:
        return 'REPEAT';
      case GamePhase.roundClear:
        return 'LOCKED IN';
      case GamePhase.failed:
        return 'SIGNAL LOST';
    }
  }

  @override
  void dispose() {
    _sessionId += 1;
    _cancelInputTimer();
    unawaited(_soundController.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFocus = widget.mode == GameMode.focus;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double bottomNavHeight = _navBarBaseHeight + bottomInset;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(color: NeuralTheme.background),
        child: Stack(
          children: [
            const _BackgroundEffects(),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  NeuralTopBar(onBack: () => Navigator.of(context).pop()),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 8, 24, bottomNavHeight),
                      child: _ScaleToFit(
                        designWidth: _gameScreenDesignWidth,
                        designHeight: _gameScreenDesignHeight,
                        child: Column(
                          children: [
                            if (isFocus)
                              _FocusDashboard(
                                score: _score,
                                streak: _streak,
                                round: _round,
                                phaseLabel: _phaseLabel,
                                progress: _sequenceProgress,
                                onReset: () => unawaited(_resetGame()),
                              )
                            else
                              _OverdriveDashboard(
                                score: _score,
                                streak: _streak,
                                round: _round,
                                phaseLabel: _phaseLabel,
                                progress: _sequenceProgress,
                                timerProgress: _timerProgress,
                                onReset: () => unawaited(_resetGame()),
                              ),
                            const SizedBox(height: 20),
                            _ModeProgress(
                              mode: widget.mode,
                              round: _round,
                              phaseLabel: _phaseLabel,
                              progress: _sequenceProgress,
                              timerProgress:
                                  _inputWindowForCurrentTurn() == null
                                  ? null
                                  : _timerProgress,
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: _GameBoard(
                                  gridSize: widget.mode.gridSize,
                                  highlightedTile: _highlightedTile,
                                  pressedTile: _pressedTile,
                                  errorTile: _errorTile,
                                  accent: widget.mode.accent,
                                  icon: widget.mode.icon,
                                  enabled: _phase == GamePhase.input,
                                  onTap: _handleTileTap,
                                ),
                              ),
                            ),
                            if (widget.settings.trainingHintsEnabled)
                              const SizedBox(height: 20),
                            if (widget.settings.trainingHintsEnabled)
                              _ModeHintCard(
                                mode: widget.mode,
                                phase: _phase,
                                round: _round,
                                tapWindow: _inputWindowForCurrentTurn(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: NeuralBottomNav(selected: NeuralNavItem.grid),
            ),
          ],
        ),
      ),
    );
  }
}

class NeuralTopBar extends StatelessWidget {
  const NeuralTopBar({
    super.key,
    this.onBack,
    this.onAction,
    this.actionIcon = Icons.settings_rounded,
  });

  final VoidCallback? onBack;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: onBack == null
                ? null
                : _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    color: NeuralTheme.surfaceHighest,
                    iconColor: NeuralTheme.textMuted,
                    onTap: onBack,
                  ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.memory_rounded, color: NeuralTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'NEURAL RECALL',
              style: TextStyle(
                color: NeuralTheme.primary,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.6,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: onAction == null
                ? null
                : _RoundIconButton(
                    icon: actionIcon,
                    color: NeuralTheme.surfaceHighest,
                    iconColor: NeuralTheme.textDim,
                    onTap: onAction,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScaleToFit extends StatelessWidget {
  const _ScaleToFit({
    required this.designWidth,
    required this.designHeight,
    required this.child,
  });

  final double designWidth;
  final double designHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(width: designWidth, height: designHeight, child: child),
      ),
    );
  }
}

class _HeroLogo extends StatelessWidget {
  const _HeroLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -3,
              right: -4,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: NeuralTheme.secondary,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: NeuralTheme.secondaryGlow.withValues(alpha: 0.65),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
            Icon(
              Icons.psychology_alt_rounded,
              size: 84,
              color: NeuralTheme.primary,
              shadows: [
                Shadow(
                  color: NeuralTheme.primaryGlow.withValues(alpha: 0.7),
                  blurRadius: 24,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'NEURAL\nRECALL',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: NeuralTheme.primary,
            fontSize: 46,
            height: 0.92,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -2.2,
            shadows: [
              Shadow(
                color: NeuralTheme.primaryGlow.withValues(alpha: 0.7),
                blurRadius: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BestStreakCard extends StatelessWidget {
  const _BestStreakCard({required this.bestStreak});

  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NeuralTheme.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: NeuralTheme.primaryGlow.withValues(alpha: 0.28),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'BEST STREAK',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: NeuralTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$bestStreak',
                style: TextStyle(
                  color: NeuralTheme.primarySoft,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: NeuralTheme.primaryGlow.withValues(alpha: 0.55),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'NODES',
                  style: TextStyle(
                    color: NeuralTheme.primarySoft.withValues(alpha: 0.7),
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.mode, required this.onTap});

  final GameMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isOverdrive = mode == GameMode.overdrive;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          height: 142,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isOverdrive
                ? NeuralTheme.secondary.withValues(alpha: 0.12)
                : NeuralTheme.surfaceHigh,
            border: Border.all(
              color: isOverdrive
                  ? NeuralTheme.secondary.withValues(alpha: 0.20)
                  : NeuralTheme.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.menuTitle,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isOverdrive
                            ? NeuralTheme.secondarySoft
                            : NeuralTheme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mode.subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: isOverdrive
                            ? NeuralTheme.secondarySoft.withValues(alpha: 0.56)
                            : NeuralTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Icon(
                mode.icon,
                size: 38,
                color: isOverdrive
                    ? NeuralTheme.secondarySoft.withValues(alpha: 0.85)
                    : NeuralTheme.primary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusDashboard extends StatelessWidget {
  const _FocusDashboard({
    required this.score,
    required this.streak,
    required this.round,
    required this.phaseLabel,
    required this.progress,
    required this.onReset,
  });

  final int score;
  final int streak;
  final int round;
  final String phaseLabel;
  final double progress;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _MetricBlock(
                label: 'CURRENT SCORE',
                value: _formatNumber(score),
                valueColor: NeuralTheme.primary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: NeuralTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: NeuralTheme.outline.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: NeuralTheme.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'R$round  |  $streak CHAIN',
                    style: TextStyle(
                      color: NeuralTheme.tertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _RoundIconButton(
              icon: Icons.restart_alt_rounded,
              color: NeuralTheme.surface,
              iconColor: NeuralTheme.textMuted,
              onTap: onReset,
            ),
          ],
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: NeuralTheme.surfaceHighest,
            valueColor: AlwaysStoppedAnimation<Color>(NeuralTheme.primary),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            phaseLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: NeuralTheme.primarySoft.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverdriveDashboard extends StatelessWidget {
  const _OverdriveDashboard({
    required this.score,
    required this.streak,
    required this.round,
    required this.phaseLabel,
    required this.progress,
    required this.timerProgress,
    required this.onReset,
  });

  final int score;
  final int streak;
  final int round;
  final String phaseLabel;
  final double progress;
  final double timerProgress;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _MetricBlock(
                label: 'CURRENT SCORE',
                value: _formatNumber(score),
                valueColor: NeuralTheme.primarySoft,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: NeuralTheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: NeuralTheme.secondarySoft.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: NeuralTheme.secondarySoft,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'R$round  |  X$streak',
                        style: TextStyle(
                          color: NeuralTheme.secondarySoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('RESET SEQUENCE'),
                  style: TextButton.styleFrom(
                    foregroundColor: NeuralTheme.textMuted,
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: NeuralTheme.surfaceHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              NeuralTheme.secondarySoft,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                phaseLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: NeuralTheme.secondarySoft.withValues(alpha: 0.80),
                ),
              ),
            ),
            SizedBox(
              width: 92,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: timerProgress,
                  minHeight: 6,
                  backgroundColor: NeuralTheme.surfaceHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    NeuralTheme.tertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: NeuralTheme.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            height: 0.95,
            shadows: [
              Shadow(color: valueColor.withValues(alpha: 0.30), blurRadius: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeProgress extends StatelessWidget {
  const _ModeProgress({
    required this.mode,
    required this.round,
    required this.phaseLabel,
    required this.progress,
    this.timerProgress,
  });

  final GameMode mode;
  final int round;
  final String phaseLabel;
  final double progress;
  final double? timerProgress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 4,
                  color: NeuralTheme.surfaceHighest,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: mode == GameMode.focus
                              ? [NeuralTheme.primary, NeuralTheme.primarySoft]
                              : [NeuralTheme.primary, NeuralTheme.secondary],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              mode.scoreLabel,
              style: TextStyle(
                color: mode == GameMode.focus
                    ? NeuralTheme.primary
                    : NeuralTheme.primarySoft,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              round == 0 ? 'ROUND 0' : 'ROUND $round',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: NeuralTheme.textMuted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                phaseLabel,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: NeuralTheme.textDim),
              ),
            ),
            if (timerProgress != null)
              SizedBox(
                width: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: timerProgress,
                    minHeight: 4,
                    backgroundColor: NeuralTheme.surfaceHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      NeuralTheme.tertiary,
                    ),
                  ),
                ),
              )
            else
              Text(
                'UNTIMED',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: NeuralTheme.primarySoft.withValues(alpha: 0.65),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GameBoard extends StatelessWidget {
  const _GameBoard({
    required this.gridSize,
    required this.highlightedTile,
    required this.pressedTile,
    required this.errorTile,
    required this.accent,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final int gridSize;
  final int? highlightedTile;
  final int? pressedTile;
  final int? errorTile;
  final Color accent;
  final IconData icon;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: NeuralTheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gridSize * gridSize,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final bool active =
                index == highlightedTile || index == pressedTile;
            return _BoardTile(
              active: active,
              error: index == errorTile,
              accent: accent,
              icon: icon,
              enabled: enabled,
              onTap: enabled ? () => onTap(index) : null,
            );
          },
        ),
      ),
    );
  }
}

class _BoardTile extends StatelessWidget {
  const _BoardTile({
    required this.active,
    required this.error,
    required this.accent,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final bool active;
  final bool error;
  final Color accent;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: error
              ? NeuralTheme.errorContainer.withValues(alpha: 0.90)
              : active
              ? accent
              : NeuralTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: error
                ? NeuralTheme.error.withValues(alpha: 0.40)
                : active
                ? NeuralTheme.primarySoft.withValues(alpha: 0.30)
                : NeuralTheme.outline.withValues(alpha: 0.12),
            width: active || error ? 2 : 1,
          ),
          boxShadow: active || error
              ? [
                  BoxShadow(
                    color: (error ? NeuralTheme.error : accent).withValues(
                      alpha: 0.45,
                    ),
                    blurRadius: 26,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: active || error
                ? 1
                : enabled
                ? 0.24
                : 0.12,
            child: Icon(
              error
                  ? Icons.close_rounded
                  : active
                  ? icon
                  : Icons.grid_4x4_rounded,
              size: active || error ? 38 : 24,
              color: active || error ? Colors.white : NeuralTheme.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeHintCard extends StatelessWidget {
  const _ModeHintCard({
    required this.mode,
    required this.phase,
    required this.round,
    required this.tapWindow,
  });

  final GameMode mode;
  final GamePhase phase;
  final int round;
  final Duration? tapWindow;

  String get _title {
    if (mode == GameMode.focus) {
      return phase == GamePhase.input ? 'FOCUS LOOP' : 'PATTERN BRIEF';
    }
    return phase == GamePhase.input ? 'OVERDRIVE LIVE' : 'RAPID SYNC';
  }

  String get _message {
    switch (phase) {
      case GamePhase.booting:
        return 'Calibrating the board. The first pattern is loading now.';
      case GamePhase.showing:
        return mode == GameMode.focus
            ? 'Watch the sequence carefully. One new tile is appended every round.'
            : 'The sequence plays at high speed. Track the pattern before the board unlocks.';
      case GamePhase.input:
        if (mode == GameMode.focus) {
          return 'Repeat the full pattern in order. Focus mode has no timer, so precision matters more than speed.';
        }
        final int tapWindowMs = tapWindow?.inMilliseconds ?? 0;
        return 'Repeat the pattern before the timer burns down. Current tap window: ${tapWindowMs}ms.';
      case GamePhase.roundClear:
        return 'Round $round completed. Prepare for one more step in the chain.';
      case GamePhase.failed:
        return 'Sequence lost. Reset the loop and rebuild the chain from round one.';
    }
  }

  IconData get _icon {
    if (mode == GameMode.focus) {
      return Icons.psychology_rounded;
    }
    return phase == GamePhase.input
        ? Icons.flash_on_rounded
        : Icons.rocket_launch_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NeuralTheme.outline.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconPlate(
            icon: _icon,
            color: mode == GameMode.focus
                ? NeuralTheme.secondary
                : NeuralTheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: NeuralTheme.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _message,
                  style: const TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetConfirmDialog extends StatelessWidget {
  const _ResetConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: NeuralTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: NeuralTheme.outline.withValues(alpha: 0.24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RESET CURRENT RUN?',
              style: TextStyle(
                color: NeuralTheme.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your active score, round, and chain will be cleared immediately.',
              style: TextStyle(
                color: NeuralTheme.textMuted,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NeuralTheme.textMuted,
                      side: BorderSide(
                        color: NeuralTheme.outline.withValues(alpha: 0.28),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('KEEP RUNNING'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: NeuralTheme.primary,
                      foregroundColor: NeuralTheme.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'RESET',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GameOverDialog extends StatelessWidget {
  const GameOverDialog({
    super.key,
    required this.mode,
    required this.score,
    required this.bestRun,
    required this.roundReached,
    required this.summary,
    required this.newHighScore,
  });

  final GameMode mode;
  final int score;
  final int bestRun;
  final int roundReached;
  final String summary;
  final bool newHighScore;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: NeuralTheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: NeuralTheme.outline.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: NeuralTheme.primaryGlow.withValues(alpha: 0.25),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -90,
              child: _GlowOrb(
                size: 180,
                color: NeuralTheme.secondary.withValues(alpha: 0.13),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -90,
              child: _GlowOrb(
                size: 180,
                color: NeuralTheme.primary.withValues(alpha: 0.08),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: NeuralTheme.errorContainer.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NeuralTheme.error.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.heart_broken_rounded,
                    color: NeuralTheme.error,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'NEURAL LINK SEVERED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: NeuralTheme.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: 48,
                  height: 3,
                  decoration: BoxDecoration(
                    color: NeuralTheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: mode.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: mode.accent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    mode.label.toUpperCase(),
                    style: TextStyle(
                      color: mode == GameMode.focus
                          ? NeuralTheme.primarySoft
                          : NeuralTheme.secondarySoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'FINAL SCORE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: NeuralTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNumber(score),
                  style: const TextStyle(
                    color: NeuralTheme.text,
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.8,
                  ),
                ),
                const SizedBox(height: 12),
                if (newHighScore)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: NeuralTheme.secondary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: NeuralTheme.secondarySoft.withValues(
                          alpha: 0.20,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          color: NeuralTheme.secondarySoft,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'NEW HIGH SCORE',
                          style: TextStyle(
                            color: NeuralTheme.secondarySoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  summary,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Best chain: $bestRun inputs  |  Round reached: $roundReached',
                  style: const TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: NeuralTheme.primary,
                      foregroundColor: NeuralTheme.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'PLAY AGAIN',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NeuralTheme.textMuted,
                      side: BorderSide(
                        color: NeuralTheme.outline.withValues(alpha: 0.30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'MAIN MENU',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum NeuralNavItem { grid, stats, settings }

class NeuralBottomNav extends StatelessWidget {
  const NeuralBottomNav({
    super.key,
    required this.selected,
    this.onItemSelected,
  });

  final NeuralNavItem selected;
  final ValueChanged<NeuralNavItem>? onItemSelected;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 10, 24, math.max(12, bottomInset)),
      decoration: BoxDecoration(
        color: NeuralTheme.background.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: NeuralTheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(
            icon: Icons.grid_view_rounded,
            selected: selected == NeuralNavItem.grid,
            onTap: () => onItemSelected?.call(NeuralNavItem.grid),
          ),
          _NavIcon(
            icon: Icons.stacked_bar_chart_rounded,
            selected: selected == NeuralNavItem.stats,
            onTap: () => onItemSelected?.call(NeuralNavItem.stats),
          ),
          _NavIcon(
            icon: Icons.settings_rounded,
            selected: selected == NeuralNavItem.settings,
            onTap: () => onItemSelected?.call(NeuralNavItem.settings),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.selected, this.onTap});

  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: selected
                ? NeuralTheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: NeuralTheme.primaryGlow.withValues(alpha: 0.45),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: selected ? NeuralTheme.primary : const Color(0xFF5D5D5D),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, color: iconColor),
      ),
    );
  }
}

class _IconPlate extends StatelessWidget {
  const _IconPlate({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _BackgroundEffects extends StatelessWidget {
  const _BackgroundEffects();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _GlowOrb(
              size: 280,
              color: NeuralTheme.primaryGlow.withValues(alpha: 0.35),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -100,
            child: _GlowOrb(
              size: 240,
              color: NeuralTheme.secondaryGlow.withValues(alpha: 0.42),
            ),
          ),
          Positioned.fill(child: _GridOverlay()),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 24)],
      ),
    );
  }
}

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.035,
      child: CustomPaint(
        painter: _DotGridPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 40;
    final Paint paint = Paint()..color = Colors.white;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatNumber(int value) {
  final String digits = value.toString();
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final int position = digits.length - i;
    buffer.write(digits[i]);
    if (position > 1 && position % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _formatAverage(double value) {
  if (value == value.roundToDouble()) {
    return _formatNumber(value.round());
  }

  return value.toStringAsFixed(1);
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return 'Never';
  }

  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final DateTime localValue = value.toLocal();
  return '${months[localValue.month - 1]} ${localValue.day}, ${localValue.year}';
}
