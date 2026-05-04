import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'stats_models.dart';
import 'stats_repository.dart';

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();

class LocalStatsRepository extends StatsRepository {
  LocalStatsRepository({LocalStatsStore? store})
    : _store = store ?? SharedPreferencesStatsStore();

  final LocalStatsStore _store;

  @override
  Future<PlayerStats> loadStats() async {
    final PlayerStats? storedStats = await _store.readStats();
    if (storedStats != null) {
      return storedStats;
    }

    final List<GameSession> sessions = await _store.readSessions();
    if (sessions.isEmpty) {
      return PlayerStats.empty();
    }

    final PlayerStats derivedStats = PlayerStats.fromSessions(sessions);
    await _store.writeStats(derivedStats);
    return derivedStats;
  }

  @override
  Future<List<GameSession>> loadSessions() {
    return _store.readSessions();
  }

  @override
  Future<void> saveCompletedSession(GameSession session) async {
    final List<GameSession> updatedSessions = <GameSession>[
      ...await _store.readSessions(),
      session,
    ];
    final PlayerStats updatedStats = PlayerStats.fromSessions(updatedSessions);

    await _store.writeSessions(updatedSessions);
    await _store.writeStats(updatedStats);
  }
}

abstract interface class LocalStatsStore {
  Future<PlayerStats?> readStats();

  Future<List<GameSession>> readSessions();

  Future<void> writeStats(PlayerStats stats);

  Future<void> writeSessions(List<GameSession> sessions);
}

class SharedPreferencesStatsStore implements LocalStatsStore {
  SharedPreferencesStatsStore({SharedPreferencesLoader? preferencesLoader})
    : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String _statsKey = 'stats.player';
  static const String _sessionsKey = 'stats.sessions';

  final SharedPreferencesLoader _preferencesLoader;

  SharedPreferences? _preferences;

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ??= await _preferencesLoader();
  }

  @override
  Future<PlayerStats?> readStats() async {
    final SharedPreferences preferences = await _getPreferences();
    final String? rawStats = preferences.getString(_statsKey);
    if (rawStats == null || rawStats.isEmpty) {
      return null;
    }

    return PlayerStats.fromMap(_decodeMap(rawStats));
  }

  @override
  Future<List<GameSession>> readSessions() async {
    final SharedPreferences preferences = await _getPreferences();
    final List<String> rawSessions =
        preferences.getStringList(_sessionsKey) ?? const <String>[];

    return rawSessions
        .map((String rawSession) => GameSession.fromMap(_decodeMap(rawSession)))
        .toList(growable: false);
  }

  @override
  Future<void> writeStats(PlayerStats stats) async {
    final SharedPreferences preferences = await _getPreferences();
    await preferences.setString(_statsKey, jsonEncode(stats.toMap()));
  }

  @override
  Future<void> writeSessions(List<GameSession> sessions) async {
    final SharedPreferences preferences = await _getPreferences();
    final List<String> encodedSessions = sessions
        .map((GameSession session) => jsonEncode(session.toMap()))
        .toList(growable: false);
    await preferences.setStringList(_sessionsKey, encodedSessions);
  }

  Map<String, Object?> _decodeMap(String rawValue) {
    return (jsonDecode(rawValue) as Map<Object?, Object?>)
        .cast<String, Object?>();
  }
}
