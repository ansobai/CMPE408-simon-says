class AppEnvironment {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://89.167.98.133',
  );

  static const String clerkPublishableKey = String.fromEnvironment(
    'CLERK_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const bool useLocalRepositories = bool.fromEnvironment(
    'USE_LOCAL_DATA',
    defaultValue: false,
  );
}
