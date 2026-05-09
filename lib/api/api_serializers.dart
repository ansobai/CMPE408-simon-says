import '../auth/auth_models.dart';
import '../stats/stats_models.dart';

AppUser appUserFromApi(Map<String, dynamic> json) {
  return AppUser.fromMap(json.cast<String, Object?>());
}

GameSession gameSessionFromApi(Map<String, dynamic> json) {
  return GameSession(
    id: json['id']! as String,
    mode: GameModeKey.fromStorage(json['mode']! as String),
    startedAt: DateTime.parse(json['started_at']! as String),
    endedAt: DateTime.parse(json['ended_at']! as String),
    score: (json['score']! as num).toInt(),
    bestStreak: (json['best_streak']! as num).toInt(),
    roundReached: (json['round_reached']! as num).toInt(),
    endReason: SessionEndReason.fromStorage(json['end_reason']! as String),
  );
}

Map<String, Object?> gameSessionToApi(GameSession session) {
  return <String, Object?>{
    'mode': session.mode.name,
    'started_at': session.startedAt.toUtc().toIso8601String(),
    'ended_at': session.endedAt.toUtc().toIso8601String(),
    'score': session.score,
    'best_streak': session.bestStreak,
    'round_reached': session.roundReached,
    'end_reason': session.endReason.name,
  };
}

PlayerStats playerStatsFromApi(Map<String, dynamic> json) {
  final Map<String, dynamic> rawBestScores =
      (json['best_score_by_mode']! as Map<Object?, Object?>)
          .cast<String, dynamic>();

  return PlayerStats(
    bestStreak: (json['best_streak']! as num).toInt(),
    bestScore: (json['best_score']! as num).toInt(),
    bestScoreByMode: <GameModeKey, int>{
      for (final GameModeKey mode in GameModeKey.values)
        mode: ((rawBestScores[mode.name] ?? 0) as num).toInt(),
    },
    totalSessions: (json['total_sessions']! as num).toInt(),
    totalScore: (json['total_score']! as num).toInt(),
    totalRoundsReached: (json['total_rounds_reached']! as num).toInt(),
    lastPlayedAt: json['last_played_at'] == null
        ? null
        : DateTime.parse(json['last_played_at']! as String),
  );
}
