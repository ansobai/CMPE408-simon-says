import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

class LocalAuthRepository extends AuthRepository {
  LocalAuthRepository({AppDatabase? database})
    : _database = database ?? AppDatabase();

  static const String _currentUserKey = 'current_user_id';

  final AppDatabase _database;

  @override
  Future<AppUser?> restoreSession() async {
    final Database db = await _database.open();
    final List<Map<String, Object?>> rows = await db.query(
      'app_state',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[_currentUserKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    final int userId = int.parse(rows.first['value']! as String);
    return loadUserById(userId);
  }

  @override
  Future<AppUser?> loadUserById(int userId) async {
    final Database db = await _database.open();
    return _queryUserById(db, userId);
  }

  @override
  Future<AppUser> signIn({
    required String username,
    required String password,
  }) async {
    final String normalizedUsername = _normalizeUsername(username);
    _validatePassword(password);
    final Database db = await _database.open();
    final List<Map<String, Object?>> rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: <Object?>[normalizedUsername],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AuthFailure(
        AuthFailureCode.invalidCredentials,
        'That username or password does not match a local account.',
      );
    }

    final Map<String, Object?> userRow = rows.first;
    final String salt = userRow['password_salt']! as String;
    final String expectedHash = userRow['password_hash']! as String;
    if (_hashPassword(password, salt) != expectedHash) {
      throw const AuthFailure(
        AuthFailureCode.invalidCredentials,
        'That username or password does not match a local account.',
      );
    }

    final AppUser user = AppUser.fromMap(userRow);
    await _persistCurrentUser(db, user.id);
    return user;
  }

  @override
  Future<AppUser> signUp({
    required String username,
    required String password,
  }) async {
    final String normalizedUsername = _normalizeUsername(username);
    _validatePassword(password);
    final Database db = await _database.open();
    final DateTime now = DateTime.now().toUtc();
    final String salt = _generateSalt();
    final String passwordHash = _hashPassword(password, salt);

    try {
      final int userId = await db.insert('users', <String, Object?>{
        'username': normalizedUsername,
        'password_hash': passwordHash,
        'password_salt': salt,
        'score': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'last_played_at': null,
      });
      await _persistCurrentUser(db, userId);
      return AppUser(
        id: userId,
        username: normalizedUsername,
        score: 0,
        createdAt: now,
        updatedAt: now,
      );
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const AuthFailure(
          AuthFailureCode.usernameTaken,
          'That username is already taken',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    final Database db = await _database.open();
    await db.delete(
      'app_state',
      where: 'key = ?',
      whereArgs: <Object?>[_currentUserKey],
    );
  }

  Future<AppUser?> _queryUserById(Database db, int userId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: <Object?>[userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      await signOut();
      return null;
    }

    return AppUser.fromMap(rows.first);
  }

  Future<void> _persistCurrentUser(Database db, int userId) async {
    await db.insert('app_state', <String, Object?>{
      'key': _currentUserKey,
      'value': userId.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _normalizeUsername(String username) {
    final String normalized = username.trim();
    if (normalized.length < 3) {
      throw const AuthFailure(
        AuthFailureCode.invalidUsername,
        'Use a username with at least 3 characters.',
      );
    }
    return normalized;
  }

  void _validatePassword(String password) {
    if (password.length < 8) {
      throw const AuthFailure(
        AuthFailureCode.invalidPassword,
        'Use a password with at least 8 characters.',
      );
    }
  }

  String _generateSalt() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(
      16,
      (_) => random.nextInt(256),
      growable: false,
    );
    return base64Url.encode(bytes);
  }

  String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt::$password')).toString();
  }
}
