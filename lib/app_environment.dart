class AppEnvironment {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const bool useLocalRepositories = bool.fromEnvironment(
    'USE_LOCAL_DATA',
    defaultValue: false,
  );
}
