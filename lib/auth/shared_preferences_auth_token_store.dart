import 'package:shared_preferences/shared_preferences.dart';

import 'auth_token_store.dart';

class SharedPreferencesAuthTokenStore implements AuthTokenStore {
  static const String _tokenKey = 'auth_access_token';

  @override
  Future<void> clearToken() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }

  @override
  Future<String?> readToken() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getString(_tokenKey);
  }

  @override
  Future<void> writeToken(String token) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }
}
