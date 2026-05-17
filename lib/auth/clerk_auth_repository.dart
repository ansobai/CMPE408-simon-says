import 'package:clerk_flutter/clerk_flutter.dart';

import '../api/api_client.dart';
import '../api/api_errors.dart';
import '../api/api_serializers.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

class ClerkAuthRepository extends AuthRepository {
  ClerkAuthRepository({
    required ApiClient apiClient,
    required ClerkAuthState auth,
  }) : _apiClient = apiClient,
       _auth = auth;

  final ApiClient _apiClient;
  final ClerkAuthState _auth;

  @override
  Future<AppUser?> loadUserById(int userId) async {
    try {
      final AppUser user = await _syncCurrentUser();
      return user.id == userId ? user : null;
    } on ApiUnauthorizedException {
      await _auth.signOut();
      rethrow;
    }
  }

  @override
  Future<AppUser?> restoreSession() async {
    if (!_auth.isSignedIn || _auth.user == null) {
      return null;
    }

    try {
      return await _syncCurrentUser();
    } on ApiUnauthorizedException {
      await _auth.signOut();
      return null;
    }
  }

  @override
  Future<AppUser> signIn({required String username, required String password}) {
    return _syncSignedInUser();
  }

  @override
  Future<void> signOut() async {
    if (_auth.isSignedIn) {
      await _auth.signOut();
    }
  }

  @override
  Future<AppUser> signUp({required String username, required String password}) {
    return _syncSignedInUser();
  }

  Future<AppUser> _syncSignedInUser() async {
    if (!_auth.isSignedIn || _auth.user == null) {
      throw const AuthFailure(
        AuthFailureCode.serviceUnavailable,
        'Use the Clerk sign-in flow to continue.',
      );
    }

    try {
      return await _syncCurrentUser();
    } on ApiRequestException catch (error) {
      throw AuthFailure(AuthFailureCode.serviceUnavailable, error.message);
    } on ApiNetworkException catch (error) {
      throw AuthFailure(AuthFailureCode.serviceUnavailable, error.message);
    }
  }

  Future<AppUser> _syncCurrentUser() async {
    final user = _auth.user;
    if (user == null) {
      throw const ApiUnauthorizedException();
    }

    final Map<String, dynamic> payload = await _apiClient.postJson(
      '/auth/sync',
      authenticated: true,
      body: <String, Object?>{
        'username': user.username,
        'name': user.hasName ? user.name : null,
        'email': user.email,
      },
    );
    return appUserFromApi(payload);
  }
}
