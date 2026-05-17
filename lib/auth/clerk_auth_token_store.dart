import 'package:clerk_auth/clerk_auth.dart' show ClerkError, SessionToken;
import 'package:clerk_flutter/clerk_flutter.dart';

import 'auth_token_store.dart';

class ClerkAuthTokenStore implements AuthTokenStore {
  const ClerkAuthTokenStore({required ClerkAuthState auth}) : _auth = auth;

  final ClerkAuthState _auth;

  @override
  Future<void> clearToken() async {
    if (_auth.isSignedIn) {
      await _auth.signOut();
    }
  }

  @override
  Future<String?> readToken() async {
    if (!_auth.isSignedIn) {
      return null;
    }

    try {
      final SessionToken token = await _auth.sessionToken();
      return token.jwt;
    } on ClerkError {
      return null;
    }
  }

  @override
  Future<void> writeToken(String token) async {
    // Clerk manages session tokens internally.
  }
}
