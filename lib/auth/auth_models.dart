import 'package:flutter/foundation.dart';

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.score,
    required this.createdAt,
    required this.updatedAt,
    this.lastPlayedAt,
  });

  final int id;
  final String username;
  final int score;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastPlayedAt;

  factory AppUser.fromMap(Map<String, Object?> map) {
    return AppUser(
      id: map['id']! as int,
      username: map['username']! as String,
      score: map['score']! as int,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
      lastPlayedAt: map['last_played_at'] == null
          ? null
          : DateTime.parse(map['last_played_at']! as String),
    );
  }
}
