import '../api/api_client.dart';
import '../api/api_errors.dart';
import '../api/api_serializers.dart';
import 'auth_models.dart';
import 'auth_repository.dart';
import 'auth_token_store.dart';

class RemoteAuthRepository extends AuthRepository {
  RemoteAuthRepository({
    required ApiClient apiClient,
    required AuthTokenStore tokenStore,
  }) : _apiClient = apiClient,
       _tokenStore = tokenStore;

  final ApiClient _apiClient;
  final AuthTokenStore _tokenStore;

  @override
  Future<AppUser?> loadUserById(int userId) async {
    try {
      final AppUser user = await _loadCurrentUser();
      return user.id == userId ? user : null;
    } on ApiUnauthorizedException {
      await _tokenStore.clearToken();
      rethrow;
    }
  }

  @override
  Future<AppUser?> restoreSession() async {
    final String? token = await _tokenStore.readToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      return await _loadCurrentUser();
    } on ApiUnauthorizedException {
      await _tokenStore.clearToken();
      return null;
    }
  }

  @override
  Future<AppUser> signIn({
    required String username,
    required String password,
  }) async {
    final String normalizedUsername = _normalizeUsername(username);
    _validatePassword(password);
    try {
      final Map<String, dynamic> payload = await _apiClient.postJson(
        '/auth/login',
        body: <String, Object?>{
          'username': normalizedUsername,
          'password': password,
        },
      );
      return _persistSession(payload);
    } on ApiUnauthorizedException {
      throw const AuthFailure(
        AuthFailureCode.invalidCredentials,
        'That username or password does not match a shared account.',
      );
    } on ApiRequestException catch (error) {
      throw AuthFailure(AuthFailureCode.serviceUnavailable, error.message);
    } on ApiNetworkException catch (error) {
      throw AuthFailure(AuthFailureCode.serviceUnavailable, error.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _apiClient.postJson('/auth/logout', authenticated: true);
    } on ApiException {
      // Local token clearing still has to happen even if the backend is down.
    } finally {
      await _tokenStore.clearToken();
    }
  }

  @override
  Future<void> deleteAccount() async {
    throw const AuthFailure(
      AuthFailureCode.serviceUnavailable,
      'This build only supports account deletion through the Clerk-backed sign-in flow.',
    );
  }

  @override
  Future<AppUser> signUp({
    required String username,
    required String password,
  }) async {
    final String normalizedUsername = _normalizeUsername(username);
    _validatePassword(password);
    try {
      final Map<String, dynamic> payload = await _apiClient.postJson(
        '/auth/register',
        body: <String, Object?>{
          'username': normalizedUsername,
          'password': password,
        },
      );
      return _persistSession(payload);
    } on ApiRequestException catch (error) {
      if (error.statusCode == 409) {
        throw const AuthFailure(
          AuthFailureCode.usernameTaken,
          'That username is already taken on the shared leaderboard.',
        );
      }
      throw AuthFailure(AuthFailureCode.serviceUnavailable, error.message);
    } on ApiNetworkException catch (error) {
      throw AuthFailure(AuthFailureCode.serviceUnavailable, error.message);
    }
  }

  Future<AppUser> _loadCurrentUser() async {
    final Map<String, dynamic> payload = await _apiClient.getJson(
      '/me',
      authenticated: true,
    );
    return appUserFromApi(payload);
  }

  Future<AppUser> _persistSession(Map<String, dynamic> payload) async {
    final String accessToken = payload['access_token']! as String;
    final AppUser user = appUserFromApi(
      (payload['user']! as Map<Object?, Object?>).cast<String, dynamic>(),
    );
    await _tokenStore.writeToken(accessToken);
    return user;
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
    if (password.length < 4) {
      throw const AuthFailure(
        AuthFailureCode.invalidPassword,
        'Use a password with at least 4 characters.',
      );
    }
  }
}
