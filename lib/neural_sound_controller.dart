import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class NeuralSoundController {
  static const List<String> _sequenceAssets = <String>[
    'audio/sequence_tier_1.wav',
    'audio/sequence_tier_2.wav',
    'audio/sequence_tier_3.wav',
    'audio/sequence_tier_4.wav',
    'audio/sequence_tier_5.wav',
  ];

  static const List<String> _tapAssets = <String>[
    'audio/tap_tier_1.wav',
    'audio/tap_tier_2.wav',
    'audio/tap_tier_3.wav',
    'audio/tap_tier_4.wav',
    'audio/tap_tier_5.wav',
  ];

  static const List<double> _sequenceVolumes = <double>[
    0.36,
    0.42,
    0.48,
    0.54,
    0.60,
  ];

  static const List<double> _tapVolumes = <double>[
    0.52,
    0.60,
    0.68,
    0.76,
    0.84,
  ];

  final List<AudioPool> _sequencePools = <AudioPool>[];
  final List<AudioPool> _tapPools = <AudioPool>[];

  Future<void>? _warmUpFuture;
  bool _audioAvailable = true;

  Future<void> warmUp() {
    return _warmUpFuture ??= _loadPools();
  }

  Future<void> _loadPools() async {
    if (!_audioAvailable) {
      return;
    }

    try {
      final List<AudioPool> sequencePools = await Future.wait(
        _sequenceAssets.map(
          (String path) => AudioPool.createFromAsset(path: path, maxPlayers: 2),
        ),
      );
      final List<AudioPool> tapPools = await Future.wait(
        _tapAssets.map(
          (String path) => AudioPool.createFromAsset(path: path, maxPlayers: 3),
        ),
      );

      _sequencePools.addAll(sequencePools);
      _tapPools.addAll(tapPools);
    } catch (error, stackTrace) {
      _audioAvailable = false;
      debugPrint('Unable to initialize game audio: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> playSequenceStep({required int streak}) async {
    await _playFamily(
      _sequencePools,
      volumeCurve: _sequenceVolumes,
      tier: _tierForStreak(streak),
    );
  }

  Future<void> playTap({
    required int streak,
    required bool completedRound,
  }) async {
    final int tier = _tierForStreak(streak);
    final double volume =
        (completedRound ? _tapVolumes[tier] + 0.06 : _tapVolumes[tier]).clamp(
          0.0,
          1.0,
        );

    await _playFamily(_tapPools, tier: tier, volumeOverride: volume);
  }

  Future<void> _playFamily(
    List<AudioPool> pools, {
    required int tier,
    List<double>? volumeCurve,
    double? volumeOverride,
  }) async {
    if (!_audioAvailable) {
      return;
    }

    await warmUp();
    if (!_audioAvailable || pools.isEmpty) {
      return;
    }

    try {
      await pools[tier].start(
        volume: volumeOverride ?? volumeCurve?[tier] ?? 1.0,
      );
    } catch (error, stackTrace) {
      _audioAvailable = false;
      debugPrint('Unable to play game audio: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  int _tierForStreak(int streak) {
    if (streak >= 22) {
      return 4;
    }
    if (streak >= 14) {
      return 3;
    }
    if (streak >= 8) {
      return 2;
    }
    if (streak >= 3) {
      return 1;
    }
    return 0;
  }

  Future<void> dispose() async {
    final Iterable<AudioPool> pools = <AudioPool>[
      ..._sequencePools,
      ..._tapPools,
    ];
    await Future.wait(pools.map((AudioPool pool) => pool.dispose()));
  }
}
