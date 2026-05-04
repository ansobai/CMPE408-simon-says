import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum AppThemeStyle {
  neon('NEON', 'neon'),
  sunset('SUNSET', 'sunset'),
  frost('FROST', 'frost');

  const AppThemeStyle(this.label, this.storageKey);

  final String label;
  final String storageKey;

  static AppThemeStyle fromStorageKey(String? value) {
    for (final AppThemeStyle style in AppThemeStyle.values) {
      if (style.storageKey == value) {
        return style;
      }
    }
    return AppThemeStyle.neon;
  }
}

@immutable
class NeuralSettings {
  const NeuralSettings({
    this.hapticsEnabled = true,
    this.reducedMotion = false,
    this.trainingHintsEnabled = true,
    this.focusAssistEnabled = false,
    this.confirmResetEnabled = true,
    this.appTheme = AppThemeStyle.neon,
  });

  final bool hapticsEnabled;
  final bool reducedMotion;
  final bool trainingHintsEnabled;
  final bool focusAssistEnabled;
  final bool confirmResetEnabled;
  final AppThemeStyle appTheme;

  NeuralSettings copyWith({
    bool? hapticsEnabled,
    bool? reducedMotion,
    bool? trainingHintsEnabled,
    bool? focusAssistEnabled,
    bool? confirmResetEnabled,
    AppThemeStyle? appTheme,
  }) {
    return NeuralSettings(
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      trainingHintsEnabled: trainingHintsEnabled ?? this.trainingHintsEnabled,
      focusAssistEnabled: focusAssistEnabled ?? this.focusAssistEnabled,
      confirmResetEnabled: confirmResetEnabled ?? this.confirmResetEnabled,
      appTheme: appTheme ?? this.appTheme,
    );
  }

  Duration tuneDuration(
    Duration duration, {
    double reducedFactor = 0.72,
    int minMilliseconds = 60,
  }) {
    if (!reducedMotion) {
      return duration;
    }

    final int scaledMs = math.max(
      minMilliseconds,
      (duration.inMilliseconds * reducedFactor).round(),
    );
    return Duration(milliseconds: scaledMs);
  }

  String get presetLabel {
    if (focusAssistEnabled && trainingHintsEnabled && reducedMotion) {
      return 'CALM';
    }
    if (!focusAssistEnabled &&
        !trainingHintsEnabled &&
        !confirmResetEnabled &&
        !hapticsEnabled) {
      return 'HARDCORE';
    }
    return 'STANDARD';
  }

  Map<String, Object> toMap() {
    return <String, Object>{
      'hapticsEnabled': hapticsEnabled,
      'reducedMotion': reducedMotion,
      'trainingHintsEnabled': trainingHintsEnabled,
      'focusAssistEnabled': focusAssistEnabled,
      'confirmResetEnabled': confirmResetEnabled,
      'appTheme': appTheme.storageKey,
    };
  }

  factory NeuralSettings.fromMap(Map<String, Object?> map) {
    return NeuralSettings(
      hapticsEnabled: map['hapticsEnabled'] as bool? ?? true,
      reducedMotion: map['reducedMotion'] as bool? ?? false,
      trainingHintsEnabled: map['trainingHintsEnabled'] as bool? ?? true,
      focusAssistEnabled: map['focusAssistEnabled'] as bool? ?? false,
      confirmResetEnabled: map['confirmResetEnabled'] as bool? ?? true,
      appTheme: AppThemeStyle.fromStorageKey(map['appTheme'] as String?),
    );
  }
}
