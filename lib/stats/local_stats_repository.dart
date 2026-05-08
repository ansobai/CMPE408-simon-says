import 'package:sqflite/sqflite.dart';

import '../auth/auth_models.dart';
import '../data/app_database.dart';
import 'stats_models.dart';
import 'stats_repository.dart';

class LocalStatsRepository extends StatsRepository {
  LocalStatsRepository({AppDatabase? database})
    : _database = database ?? AppDatabase();

  final AppDatabase _database;

  @override
  Future<PlayerStats> loadStatsForUser(int userId) async {
    final List<GameSession> sessions = await loadSessionsForUser(userId);
    if (sessions.isEmpty) {
      return PlayerStats.empty();
    }

    return PlayerStats.fromSessions(sessions);
  }

  @override
  Future<List<GameSession>> loadSessionsForUser(int userId) async {
    final Database db = await _database.open();
    final List<Map<String, Object?>> rows = await db.query(
      'game_sessions',
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'ended_at DESC',
    );

    return rows.map(_mapSession).toList(growable: false);
  }

  @override
  Future<void> saveCompletedSession({
    required int userId,
    required GameSession session,
  }) async {
    final Database db = await _database.open();
    await db.transaction((Transaction txn) async {
      await txn.insert('game_sessions', <String, Object?>{
        'id': session.id,
        'user_id': userId,
        'mode': session.mode.name,
        'started_at': session.startedAt.toIso8601String(),
        'ended_at': session.endedAt.toIso8601String(),
        'score': session.score,
        'best_streak': session.bestStreak,
        'round_reached': session.roundReached,
        'end_reason': session.endReason.name,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.rawUpdate(
        '''
        UPDATE users
        SET
          score = CASE WHEN score < ? THEN ? ELSE score END,
          updated_at = ?,
          last_played_at = ?
        WHERE id = ?
        ''',
        <Object?>[
          session.score,
          session.score,
          session.endedAt.toUtc().toIso8601String(),
          session.endedAt.toUtc().toIso8601String(),
          userId,
        ],
      );
    });
  }

  @override
  Future<List<AppUser>> loadLeaderboardUsers({int? limit}) async {
    final Database db = await _database.open();
    final List<Map<String, Object?>> rows = await db.query(
      'users',
      orderBy: 'score DESC, last_played_at DESC, username COLLATE NOCASE ASC',
      limit: limit,
    );
    return rows.map(AppUser.fromMap).toList(growable: false);
  }

  GameSession _mapSession(Map<String, Object?> row) {
    return GameSession(
      id: row['id']! as String,
      mode: GameModeKey.fromStorage(row['mode']! as String),
      startedAt: DateTime.parse(row['started_at']! as String),
      endedAt: DateTime.parse(row['ended_at']! as String),
      score: row['score']! as int,
      bestStreak: row['best_streak']! as int,
      roundReached: row['round_reached']! as int,
      endReason: SessionEndReason.fromStorage(row['end_reason']! as String),
    );
  }
}
