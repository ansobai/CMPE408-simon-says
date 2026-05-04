import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum AppThemeProfile {
  neuralBlue('neural_blue'),
  emberGlow('ember_glow'),
  mintCircuit('mint_circuit');

  const AppThemeProfile(this.storageKey);

  final String storageKey;

  static AppThemeProfile fromStorageKey(String? value) {
    for (final AppThemeProfile profile in AppThemeProfile.values) {
      if (profile.storageKey == value) {
        return profile;
      }
    }
    return AppThemeProfile.neuralBlue;
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

  Map<String, Object> toMap() {
    return <String, Object>{
      'hapticsEnabled': hapticsEnabled,
      'reducedMotion': reducedMotion,
      'trainingHintsEnabled': trainingHintsEnabled,
      'confirmResetEnabled': confirmResetEnabled,
      'soundEnabled': soundEnabled,
      'soundLevel': soundLevel,
      'sequenceSpeed': sequenceSpeed,
      'overdriveWindowScale': overdriveWindowScale,
      'appTheme': appTheme.storageKey,
    };
  }

  factory NeuralSettings.fromMap(Map<String, Object?> map) {
    return NeuralSettings(
      hapticsEnabled: map['hapticsEnabled'] as bool? ?? true,
      reducedMotion: map['reducedMotion'] as bool? ?? false,
      trainingHintsEnabled: map['trainingHintsEnabled'] as bool? ?? true,
      confirmResetEnabled: map['confirmResetEnabled'] as bool? ?? true,
      soundEnabled: map['soundEnabled'] as bool? ?? true,
      soundLevel: (map['soundLevel'] as num?)?.toDouble() ?? 0.76,
      sequenceSpeed: (map['sequenceSpeed'] as num?)?.toDouble() ?? 1.0,
      overdriveWindowScale:
          (map['overdriveWindowScale'] as num?)?.toDouble() ?? 1.0,
      appTheme: AppThemeProfile.fromStorageKey(map['appTheme'] as String?),
    );
  }
}
