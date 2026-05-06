import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({
    DatabaseFactory? databaseFactory,
    this.databaseName = 'neural_recall.db',
  }) : _databaseFactory = databaseFactory;

  final DatabaseFactory? _databaseFactory;
  final String databaseName;

  Database? _database;

  Future<Database> open() async {
    final Database existingDatabase = _database ?? await _openDatabase();
    _database = existingDatabase;
    return existingDatabase;
  }

  Future<void> close() async {
    final Database? existingDatabase = _database;
    _database = null;
    await existingDatabase?.close();
  }

  Future<Database> _openDatabase() async {
    final DatabaseFactory factory = _databaseFactory ?? databaseFactory;
    final String databasePath = databaseName == ':memory:'
        ? ':memory:'
        : path.join(await factory.getDatabasesPath(), databaseName);

    return factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (Database db, int version) async {
          await _createSchema(db);
        },
      ),
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        score INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_played_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE game_sessions (
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        mode TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT NOT NULL,
        score INTEGER NOT NULL,
        best_streak INTEGER NOT NULL,
        round_reached INTEGER NOT NULL,
        end_reason TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_game_sessions_user_id ON game_sessions(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_game_sessions_ended_at ON game_sessions(ended_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_users_score ON users(score DESC, last_played_at DESC)',
    );
  }
}
