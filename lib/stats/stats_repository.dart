import 'stats_models.dart';

abstract class StatsRepository {
  const StatsRepository();

  Future<PlayerStats> loadStats();

  Future<List<GameSession>> loadSessions();

  Future<void> saveCompletedSession(GameSession session);
}
