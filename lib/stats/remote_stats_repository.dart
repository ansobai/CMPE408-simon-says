import '../api/api_client.dart';
import '../api/api_serializers.dart';
import '../auth/auth_models.dart';
import 'stats_models.dart';
import 'stats_repository.dart';

class RemoteStatsRepository extends StatsRepository {
  RemoteStatsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<AppUser>> loadLeaderboardUsers({int? limit}) async {
    final Map<String, dynamic> payload = await _apiClient.getJson(
      '/leaderboard',
      queryParameters: <String, Object?>{'limit': limit},
    );
    final List<dynamic> users = payload['users']! as List<dynamic>;
    return users
        .map(
          (dynamic item) => appUserFromApi(
            (item as Map<Object?, Object?>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<GameSession>> loadSessionsForUser(int userId) async {
    final Map<String, dynamic> payload = await _apiClient.getJson(
      '/sessions/me',
      authenticated: true,
    );
    final List<dynamic> sessions = payload['sessions']! as List<dynamic>;
    return sessions
        .map(
          (dynamic item) => gameSessionFromApi(
            (item as Map<Object?, Object?>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<PlayerStats> loadStatsForUser(int userId) async {
    final Map<String, dynamic> payload = await _apiClient.getJson(
      '/stats/me',
      authenticated: true,
    );
    return playerStatsFromApi(payload);
  }

  @override
  Future<void> saveCompletedSession({
    required int userId,
    required GameSession session,
  }) async {
    await _apiClient.postJson(
      '/sessions',
      authenticated: true,
      body: gameSessionToApi(session),
    );
  }
}
