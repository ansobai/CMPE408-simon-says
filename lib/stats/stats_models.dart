import 'package:flutter/foundation.dart';

enum GameModeKey {
  focus,
  overdrive;

  static GameModeKey fromStorage(String value) {
    return GameModeKey.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => throw FormatException('Unknown game mode: $value'),
    );
  }
}

enum SessionEndReason {
  wrongTile,
  timedOut;

  static SessionEndReason fromStorage(String value) {
    return SessionEndReason.values.firstWhere(
      (reason) => reason.name == value,
      orElse: () => throw FormatException('Unknown session end reason: $value'),
    );
  }
}

enum SessionViewFilter {
  all('All Runs', null),
  focus('Focus', GameModeKey.focus),
  overdrive('Overdrive', GameModeKey.overdrive);

  const SessionViewFilter(this.label, this.mode);

  final String label;
  final GameModeKey? mode;
}

@immutable
class GameSession {
  const GameSession({
    required this.id,
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.score,
    required this.bestStreak,
    required this.roundReached,
    required this.endReason,
  });

  final String id;
  final GameModeKey mode;
  final DateTime startedAt;
  final DateTime endedAt;
  final int score;
  final int bestStreak;
  final int roundReached;
  final SessionEndReason endReason;

  Duration get duration => endedAt.difference(startedAt);

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'mode': mode.name,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'score': score,
      'bestStreak': bestStreak,
      'roundReached': roundReached,
      'endReason': endReason.name,
    };
  }

  factory GameSession.fromMap(Map<String, Object?> map) {
    return GameSession(
      id: map['id']! as String,
      mode: GameModeKey.fromStorage(map['mode']! as String),
      startedAt: DateTime.parse(map['startedAt']! as String),
      endedAt: DateTime.parse(map['endedAt']! as String),
      score: map['score']! as int,
      bestStreak: map['bestStreak']! as int,
      roundReached: map['roundReached']! as int,
      endReason: SessionEndReason.fromStorage(map['endReason']! as String),
    );
  }
}

@immutable
class PlayerStats {
  PlayerStats({
    required this.bestStreak,
    required this.bestScore,
    required Map<GameModeKey, int> bestScoreByMode,
    required this.totalSessions,
    required this.totalScore,
    required this.totalRoundsReached,
    required this.lastPlayedAt,
  }) : bestScoreByMode = Map<GameModeKey, int>.unmodifiable(bestScoreByMode);

  factory PlayerStats.empty() {
    return PlayerStats(
      bestStreak: 0,
      bestScore: 0,
      bestScoreByMode: <GameModeKey, int>{
        for (final GameModeKey mode in GameModeKey.values) mode: 0,
      },
      totalSessions: 0,
      totalScore: 0,
      totalRoundsReached: 0,
      lastPlayedAt: null,
    );
  }

  factory PlayerStats.fromSessions(Iterable<GameSession> sessions) {
    int bestStreak = 0;
    int bestScore = 0;
    int totalSessions = 0;
    int totalScore = 0;
    int totalRoundsReached = 0;
    DateTime? lastPlayedAt;
    final Map<GameModeKey, int> bestScoreByMode = <GameModeKey, int>{
      for (final GameModeKey mode in GameModeKey.values) mode: 0,
    };

    for (final GameSession session in sessions) {
      totalSessions += 1;
      totalScore += session.score;
      totalRoundsReached += session.roundReached;
      if (session.bestStreak > bestStreak) {
        bestStreak = session.bestStreak;
      }
      if (session.score > bestScore) {
        bestScore = session.score;
      }
      if (session.score > (bestScoreByMode[session.mode] ?? 0)) {
        bestScoreByMode[session.mode] = session.score;
      }
      if (lastPlayedAt == null || session.endedAt.isAfter(lastPlayedAt)) {
        lastPlayedAt = session.endedAt;
      }
    }

    return PlayerStats(
      bestStreak: bestStreak,
      bestScore: bestScore,
      bestScoreByMode: bestScoreByMode,
      totalSessions: totalSessions,
      totalScore: totalScore,
      totalRoundsReached: totalRoundsReached,
      lastPlayedAt: lastPlayedAt,
    );
  }

  final int bestStreak;
  final int bestScore;
  final Map<GameModeKey, int> bestScoreByMode;
  final int totalSessions;
  final int totalScore;
  final int totalRoundsReached;
  final DateTime? lastPlayedAt;

  double get averageScore =>
      totalSessions == 0 ? 0 : totalScore / totalSessions;

  double get averageRoundsReached {
    return totalSessions == 0 ? 0 : totalRoundsReached / totalSessions;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'bestStreak': bestStreak,
      'bestScore': bestScore,
      'bestScoreByMode': <String, int>{
        for (final MapEntry<GameModeKey, int> entry in bestScoreByMode.entries)
          entry.key.name: entry.value,
      },
      'totalSessions': totalSessions,
      'totalScore': totalScore,
      'totalRoundsReached': totalRoundsReached,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    };
  }

  factory PlayerStats.fromMap(Map<String, Object?> map) {
    final Map<String, Object?> rawBestScores =
        (map['bestScoreByMode']! as Map<Object?, Object?>)
            .cast<String, Object?>();

    return PlayerStats(
      bestStreak: map['bestStreak']! as int,
      bestScore: map['bestScore']! as int,
      bestScoreByMode: <GameModeKey, int>{
        for (final GameModeKey mode in GameModeKey.values)
          mode: (rawBestScores[mode.name] ?? 0) as int,
      },
      totalSessions: map['totalSessions']! as int,
      totalScore: map['totalScore']! as int,
      totalRoundsReached: map['totalRoundsReached']! as int,
      lastPlayedAt: map['lastPlayedAt'] == null
          ? null
          : DateTime.parse(map['lastPlayedAt']! as String),
    );
  }

  PlayerStats copyWith({
    int? bestStreak,
    int? bestScore,
    Map<GameModeKey, int>? bestScoreByMode,
    int? totalSessions,
    int? totalScore,
    int? totalRoundsReached,
    DateTime? lastPlayedAt,
    bool clearLastPlayedAt = false,
  }) {
    return PlayerStats(
      bestStreak: bestStreak ?? this.bestStreak,
      bestScore: bestScore ?? this.bestScore,
      bestScoreByMode: bestScoreByMode ?? this.bestScoreByMode,
      totalSessions: totalSessions ?? this.totalSessions,
      totalScore: totalScore ?? this.totalScore,
      totalRoundsReached: totalRoundsReached ?? this.totalRoundsReached,
      lastPlayedAt: clearLastPlayedAt
          ? null
          : lastPlayedAt ?? this.lastPlayedAt,
    );
  }
}

extension GameSessionCollections on Iterable<GameSession> {
  List<GameSession> leaderboard({
    GameModeKey? mode,
    int limit = 5,
  }) {
    // Rank by score first, then prefer stronger runs and newer attempts.
    final List<GameSession> sortedSessions = _filterByMode(mode).toList()
      ..sort((GameSession left, GameSession right) {
        final int byScore = right.score.compareTo(left.score);
        if (byScore != 0) {
          return byScore;
        }

        final int byStreak = right.bestStreak.compareTo(left.bestStreak);
        if (byStreak != 0) {
          return byStreak;
        }

        final int byRound = right.roundReached.compareTo(left.roundReached);
        if (byRound != 0) {
          return byRound;
        }

        return right.endedAt.compareTo(left.endedAt);
      });

    return List<GameSession>.unmodifiable(sortedSessions.take(limit));
  }

  List<GameSession> recentRuns({
    GameModeKey? mode,
    int limit = 6,
  }) {
    final List<GameSession> sortedSessions = _filterByMode(mode).toList()
      ..sort(
        (GameSession left, GameSession right) =>
            right.endedAt.compareTo(left.endedAt),
      );

    return List<GameSession>.unmodifiable(sortedSessions.take(limit));
  }

  Iterable<GameSession> _filterByMode(GameModeKey? mode) {
    if (mode == null) {
      return this;
    }

    return where((GameSession session) => session.mode == mode);
  }
}
