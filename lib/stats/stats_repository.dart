import 'stats_models.dart';
import '../auth/auth_models.dart';

abstract class StatsRepository {
  const StatsRepository();

  Future<PlayerStats> loadStatsForUser(int userId);

  Future<List<GameSession>> loadSessionsForUser(int userId);

  Future<void> saveCompletedSession({
    required int userId,
    required GameSession session,
  });

  Future<List<AppUser>> loadLeaderboardUsers({int? limit});
}
