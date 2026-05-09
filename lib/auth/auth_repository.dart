import 'auth_models.dart';

enum AuthFailureCode {
  invalidCredentials,
  usernameTaken,
  invalidUsername,
  invalidPassword,
  serviceUnavailable,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);

  final AuthFailureCode code;
  final String message;

  @override
  String toString() => 'AuthFailure($code, $message)';
}

abstract class AuthRepository {
  const AuthRepository();

  Future<AppUser?> restoreSession();

  Future<AppUser?> loadUserById(int userId);

  Future<AppUser> signIn({required String username, required String password});

  Future<AppUser> signUp({required String username, required String password});

  Future<void> signOut();
}
