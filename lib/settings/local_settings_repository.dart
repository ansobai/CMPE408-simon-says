import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import 'neural_settings.dart';
import 'settings_repository.dart';

class LocalSettingsRepository extends SettingsRepository {
  LocalSettingsRepository({AppDatabase? database})
    : _database = database ?? AppDatabase();

  static const String _settingsKey = 'settings.neural';

  final AppDatabase _database;

  @override
  Future<NeuralSettings> loadSettings() async {
    final Database db = await _database.open();
    final List<Map<String, Object?>> rows = await db.query(
      'settings',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[_settingsKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const NeuralSettings();
    }

    final String rawSettings = rows.first['value']! as String;
    return NeuralSettings.fromMap(_decodeMap(rawSettings));
  }

  @override
  Future<void> saveSettings(NeuralSettings settings) async {
    final Database db = await _database.open();
    await db.insert('settings', <String, Object?>{
      'key': _settingsKey,
      'value': jsonEncode(settings.toMap()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, Object?> _decodeMap(String rawValue) {
    return (jsonDecode(rawValue) as Map<Object?, Object?>)
        .cast<String, Object?>();
  }
}
