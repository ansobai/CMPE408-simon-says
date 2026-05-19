import 'dart:async';
import 'dart:math' as math;

import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/api_client.dart';
import 'api/api_errors.dart';
import 'app_environment.dart';
import 'auth/auth_models.dart';
import 'auth/clerk_auth_repository.dart';
import 'auth/clerk_auth_token_store.dart';
import 'auth/auth_repository.dart';
import 'auth/local_auth_repository.dart';
import 'auth/remote_auth_repository.dart';
import 'auth/shared_preferences_auth_token_store.dart';
import 'neural_sound_controller.dart';
import 'settings/local_settings_repository.dart';
import 'settings/neural_settings.dart';
import 'settings/settings_repository.dart';
import 'stats/local_stats_repository.dart';
import 'stats/remote_stats_repository.dart';
import 'stats/stats_models.dart';
import 'stats/stats_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureFullscreenUi();
  runApp(_buildRootApp());
}

Widget _buildRootApp() {
  if (AppEnvironment.useLocalRepositories) {
    return const NeuralRecallApp();
  }

  if (AppEnvironment.clerkPublishableKey.isEmpty) {
    return const _MissingClerkConfigurationApp();
  }

  return ClerkAuth(
    config: ClerkAuthConfig(publishableKey: AppEnvironment.clerkPublishableKey),
    child: ClerkAuthBuilder(
      builder: (context, authState) {
        return NeuralRecallApp(clerkAuthState: authState);
      },
    ),
  );
}

class NeuralRecallApp extends StatefulWidget {
  const NeuralRecallApp({
    super.key,
    this.authRepository,
    this.statsRepository,
    this.settingsRepository,
    this.clerkAuthState,
  });

  final AuthRepository? authRepository;
  final StatsRepository? statsRepository;
  final SettingsRepository? settingsRepository;
  final ClerkAuthState? clerkAuthState;

  @override
  State<NeuralRecallApp> createState() => _NeuralRecallAppState();
}

class _NeuralRecallAppState extends State<NeuralRecallApp> {
  final ValueNotifier<AppUser?> _currentUser = ValueNotifier<AppUser?>(null);
  final ValueNotifier<PlayerStats> _playerStats = ValueNotifier<PlayerStats>(
    PlayerStats.empty(),
  );
  final ValueNotifier<List<GameSession>> _sessions =
      ValueNotifier<List<GameSession>>(<GameSession>[]);
  final ValueNotifier<List<AppUser>> _leaderboardUsers =
      ValueNotifier<List<AppUser>>(<AppUser>[]);
  final ValueNotifier<_AppNotice?> _appNotice = ValueNotifier<_AppNotice?>(
    null,
  );
  final ValueNotifier<NeuralSettings> _settings = ValueNotifier<NeuralSettings>(
    const NeuralSettings(),
  );
  late final AuthRepository _authRepository;
  late final StatsRepository _statsRepository;
  late final SettingsRepository _settingsRepository;
  ApiClient? _ownedApiClient;
  bool _isLoadingAppState = true;
  bool _isReconcilingClerkSession = false;

  @override
  void initState() {
    super.initState();
    _settingsRepository =
        widget.settingsRepository ?? LocalSettingsRepository();
    if (AppEnvironment.useLocalRepositories) {
      _authRepository = widget.authRepository ?? LocalAuthRepository();
      _statsRepository = widget.statsRepository ?? LocalStatsRepository();
    } else if (widget.clerkAuthState != null) {
      final ClerkAuthTokenStore tokenStore = ClerkAuthTokenStore(
        auth: widget.clerkAuthState!,
      );
      _ownedApiClient = ApiClient(
        baseUrl: AppEnvironment.apiBaseUrl,
        tokenStore: tokenStore,
      );
      _authRepository =
          widget.authRepository ??
          ClerkAuthRepository(
            apiClient: _ownedApiClient!,
            auth: widget.clerkAuthState!,
          );
      _statsRepository =
          widget.statsRepository ??
          RemoteStatsRepository(apiClient: _ownedApiClient!);
      widget.clerkAuthState!.addListener(_handleClerkAuthStateChanged);
    } else {
      final SharedPreferencesAuthTokenStore tokenStore =
          SharedPreferencesAuthTokenStore();
      _ownedApiClient = ApiClient(
        baseUrl: AppEnvironment.apiBaseUrl,
        tokenStore: tokenStore,
      );
      _authRepository =
          widget.authRepository ??
          RemoteAuthRepository(
            apiClient: _ownedApiClient!,
            tokenStore: tokenStore,
          );
      _statsRepository =
          widget.statsRepository ??
          RemoteStatsRepository(apiClient: _ownedApiClient!);
    }
    WidgetsBinding.instance.addObserver(_fullscreenObserver);
    unawaited(_loadPersistedAppState());
  }

  void _handleClerkAuthStateChanged() {
    final ClerkAuthState? authState = widget.clerkAuthState;
    if (authState == null || _isLoadingAppState || _isReconcilingClerkSession) {
      return;
    }

    if (!authState.isSignedIn || authState.user == null) {
      if (_currentUser.value != null) {
        _reconcileSignedOutClerkState();
      }
      return;
    }

    if (_currentUser.value == null) {
      unawaited(_reconcileSignedInClerkState());
    }
  }

  Future<void> _loadPersistedAppState() async {
    AppUser? currentUser;
    PlayerStats stats = PlayerStats.empty();
    List<GameSession> sessions = <GameSession>[];
    List<AppUser> leaderboardUsers = <AppUser>[];
    NeuralSettings settings = const NeuralSettings();
    bool recoveredSettings = false;
    bool authServiceUnavailable = false;
    bool leaderboardUnavailable = false;
    bool signedInDataUnavailable = false;
    bool sessionExpired = false;

    try {
      currentUser = await _authRepository.restoreSession();
    } on ApiException {
      authServiceUnavailable = true;
    } catch (_) {
      authServiceUnavailable = true;
    }

    try {
      leaderboardUsers = await _statsRepository.loadLeaderboardUsers();
    } on ApiException {
      leaderboardUsers = <AppUser>[];
      leaderboardUnavailable = true;
    } catch (_) {
      leaderboardUsers = <AppUser>[];
      leaderboardUnavailable = true;
    }

    if (currentUser != null) {
      try {
        final _SignedInState signedInState = await _fetchSignedInData(
          currentUser.id,
        );
        currentUser = signedInState.user;
        sessions = signedInState.sessions;
        stats = signedInState.stats;
        leaderboardUsers = signedInState.leaderboardUsers;
      } on ApiUnauthorizedException {
        await _authRepository.signOut();
        currentUser = null;
        sessions = <GameSession>[];
        stats = PlayerStats.empty();
        sessionExpired = true;
      } on ApiException {
        sessions = <GameSession>[];
        stats = PlayerStats.empty();
        signedInDataUnavailable = true;
      } catch (_) {
        sessions = <GameSession>[];
        stats = PlayerStats.empty();
        signedInDataUnavailable = true;
      }
    }

    try {
      settings = await _settingsRepository.loadSettings();
    } catch (_) {
      settings = const NeuralSettings();
      recoveredSettings = true;
    }

    if (!mounted) {
      return;
    }

    _currentUser.value = currentUser;
    _playerStats.value = stats;
    _sessions.value = List<GameSession>.unmodifiable(sessions);
    _leaderboardUsers.value = List<AppUser>.unmodifiable(leaderboardUsers);
    _settings.value = settings;
    if (sessionExpired) {
      _showNotice(
        const _AppNotice(
          title: 'Your session expired',
          message:
              'Sign in again to refresh your shared account, stats, and score history.',
          icon: Icons.lock_clock_rounded,
          tone: _AppNoticeTone.warning,
        ),
      );
    } else if (signedInDataUnavailable) {
      _showNotice(
        const _AppNotice(
          title: 'Shared account data could not be loaded',
          message:
              'Your sign-in state is intact, but sessions, stats, or leaderboard data could not be fetched from the shared backend yet.',
          icon: Icons.cloud_off_rounded,
          tone: _AppNoticeTone.warning,
        ),
      );
    } else if (authServiceUnavailable && leaderboardUnavailable) {
      _showNotice(
        const _AppNotice(
          title: 'Shared service unavailable',
          message:
              'The app could not reach the shared auth or leaderboard service. Check the API host and try again.',
          icon: Icons.portable_wifi_off_rounded,
          tone: _AppNoticeTone.warning,
        ),
      );
    } else if (authServiceUnavailable) {
      _showNotice(
        const _AppNotice(
          title: 'Shared auth unavailable',
          message:
              'The app could not verify the saved access token, so sign-in is unavailable until the backend responds again.',
          icon: Icons.portable_wifi_off_rounded,
          tone: _AppNoticeTone.warning,
        ),
      );
    } else if (leaderboardUnavailable) {
      _showNotice(
        const _AppNotice(
          title: 'Leaderboard unavailable',
          message:
              'The shared leaderboard could not be loaded right now. Core app screens still work, and scores can sync again once the backend returns.',
          icon: Icons.leaderboard_rounded,
          tone: _AppNoticeTone.warning,
        ),
      );
    } else if (recoveredSettings) {
      _showNotice(
        const _AppNotice(
          title: 'Saved settings could not be loaded',
          message:
              'The app switched to the default visual and gameplay settings for this launch.',
          icon: Icons.tune_rounded,
          tone: _AppNoticeTone.warning,
        ),
      );
    }
    setState(() {
      _isLoadingAppState = false;
    });
  }

  Future<void> _saveCompletedSession(GameSession session) async {
    final AppUser? currentUser = _currentUser.value;
    if (currentUser == null) {
      return;
    }

    try {
      await _statsRepository.saveCompletedSession(
        userId: currentUser.id,
        session: session,
      );
      await _reloadSignedInData(currentUser.id);
      if (!mounted) {
        return;
      }
    } on ApiUnauthorizedException {
      await _handleExpiredSession();
    } on ApiException {
      if (!mounted) {
        return;
      }

      _showNotice(
        const _AppNotice(
          title: 'This run could not be saved',
          message:
              'The run finished normally, but the shared backend did not accept the session, so your synced stats and leaderboard rank were left unchanged.',
          icon: Icons.save_as_rounded,
          tone: _AppNoticeTone.warning,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showNotice(
        const _AppNotice(
          title: 'This run could not be saved',
          message:
              'The run finished normally, but the shared backend did not accept the session, so your synced stats and leaderboard rank were left unchanged.',
          icon: Icons.save_as_rounded,
          tone: _AppNoticeTone.warning,
        ),
      );
    }
  }

  Future<_SignedInState> _fetchSignedInData(int userId) async {
    final AppUser? refreshedUser = await _authRepository.loadUserById(userId);
    final List<GameSession> sessions = await _statsRepository
        .loadSessionsForUser(userId);
    final PlayerStats stats = await _statsRepository.loadStatsForUser(userId);
    final List<AppUser> leaderboardUsers = await _statsRepository
        .loadLeaderboardUsers();
    return _SignedInState(
      user: refreshedUser,
      sessions: sessions,
      stats: stats,
      leaderboardUsers: leaderboardUsers,
    );
  }

  void _applySignedInState(_SignedInState signedInState) {
    _currentUser.value = signedInState.user;
    _sessions.value = List<GameSession>.unmodifiable(signedInState.sessions);
    _playerStats.value = signedInState.stats;
    _leaderboardUsers.value = List<AppUser>.unmodifiable(
      signedInState.leaderboardUsers,
    );
  }

  Future<void> _reloadSignedInData(int userId) async {
    final _SignedInState signedInState = await _fetchSignedInData(userId);
    if (!mounted) {
      return;
    }

    _applySignedInState(signedInState);
  }

  void _updateSettings(NeuralSettings nextSettings) {
    _settings.value = nextSettings;
    unawaited(_persistSettings(nextSettings));
  }

  Future<void> _persistSettings(NeuralSettings nextSettings) async {
    try {
      await _settingsRepository.saveSettings(nextSettings);
    } catch (_) {
      if (!mounted) {
        return;
      }

      // Keep the current in-memory value, but explain that it was not stored.
      _showNotice(
        const _AppNotice(
          title: 'Settings changed, but they were not saved',
          message:
              'Your current theme and gameplay preferences will stay active until the app closes.',
          icon: Icons.settings_backup_restore_rounded,
          tone: _AppNoticeTone.warning,
        ),
      );
    }
  }

  void _showNotice(_AppNotice notice) {
    _appNotice.value = notice;
  }

  void _clearNotice() {
    _appNotice.value = null;
  }

  Future<void> _handleSignedIn(AppUser user) async {
    if (mounted) {
      setState(() {
        _isLoadingAppState = true;
      });
    }
    try {
      await _reloadSignedInData(user.id);
    } on ApiUnauthorizedException {
      await _handleExpiredSession();
    } on ApiException {
      if (mounted) {
        _currentUser.value = user;
        _playerStats.value = PlayerStats.empty();
        _sessions.value = const <GameSession>[];
        _showNotice(
          const _AppNotice(
            title: 'Account data could not be loaded',
            message:
                'The sign-in worked, but sessions, stats, or leaderboard data could not be fetched from the shared backend yet.',
            icon: Icons.lock_open_rounded,
            tone: _AppNoticeTone.warning,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        _currentUser.value = user;
        _playerStats.value = PlayerStats.empty();
        _sessions.value = const <GameSession>[];
        _showNotice(
          const _AppNotice(
            title: 'Account data could not be loaded',
            message:
                'The sign-in worked, but sessions, stats, or leaderboard data could not be fetched from the shared backend yet.',
            icon: Icons.lock_open_rounded,
            tone: _AppNoticeTone.warning,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAppState = false;
        });
      }
    }
  }

  Future<void> _reconcileSignedInClerkState() async {
    if (_isReconcilingClerkSession) {
      return;
    }

    _isReconcilingClerkSession = true;
    try {
      final AppUser? user = await _authRepository.restoreSession();
      if (user == null || !mounted) {
        return;
      }
      await _handleSignedIn(user);
    } on ApiUnauthorizedException {
      await _handleExpiredSession();
    } finally {
      _isReconcilingClerkSession = false;
    }
  }

  void _reconcileSignedOutClerkState() {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentUser.value = null;
      _playerStats.value = PlayerStats.empty();
      _sessions.value = const <GameSession>[];
      _leaderboardUsers.value = const <AppUser>[];
      _clearNotice();
    });
  }

  Future<void> _handleExpiredSession() async {
    await _authRepository.signOut();
    if (!mounted) {
      return;
    }

    setState(() {
      _currentUser.value = null;
      _playerStats.value = PlayerStats.empty();
      _sessions.value = const <GameSession>[];
      _leaderboardUsers.value = const <AppUser>[];
      _showNotice(
        const _AppNotice(
          title: 'Your session expired',
          message:
              'Sign in again to continue syncing scores, stats, and recent runs.',
          icon: Icons.lock_clock_rounded,
          tone: _AppNoticeTone.warning,
        ),
      );
    });
  }

  Future<void> _signOut() async {
    await _authRepository.signOut();
    if (!mounted) {
      return;
    }

    setState(() {
      _currentUser.value = null;
      _playerStats.value = PlayerStats.empty();
      _sessions.value = const <GameSession>[];
      _leaderboardUsers.value = const <AppUser>[];
      _clearNotice();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_fullscreenObserver);
    widget.clerkAuthState?.removeListener(_handleClerkAuthStateChanged);
    _ownedApiClient?.close();
    _currentUser.dispose();
    _playerStats.dispose();
    _sessions.dispose();
    _leaderboardUsers.dispose();
    _appNotice.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NeuralSettings>(
      valueListenable: _settings,
      builder: (context, currentSettings, _) {
        NeuralTheme.activate(currentSettings.appTheme);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: NeuralTheme.materialTheme,
          home: _isLoadingAppState
              ? const _StartupLoadingScreen()
              : _currentUser.value == null
              ? Stack(
                  children: [
                    widget.clerkAuthState != null
                        ? const _ClerkAuthScreen()
                        : _LocalAuthScreen(
                            authRepository: _authRepository,
                            onAuthenticated: _handleSignedIn,
                          ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          child: ValueListenableBuilder<_AppNotice?>(
                            valueListenable: _appNotice,
                            builder: (context, notice, _) {
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: notice == null
                                    ? const SizedBox.shrink()
                                    : _AppNoticeBanner(
                                        key: ValueKey<String>(
                                          '${notice.title}:${notice.message}',
                                        ),
                                        notice: notice,
                                        onDismiss: _clearNotice,
                                      ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : _NeuralHomeShell(
                  currentUser: _currentUser,
                  playerStats: _playerStats,
                  sessions: _sessions,
                  leaderboardUsers: _leaderboardUsers,
                  appNotice: _appNotice,
                  settings: _settings,
                  onSessionCompleted: _saveCompletedSession,
                  onDismissNotice: _clearNotice,
                  onSettingsChanged: _updateSettings,
                  onSignOut: _signOut,
                ),
        );
      },
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeuralTheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: NeuralTheme.primary),
            SizedBox(height: 20),
            Text(
              'Loading neural profile...',
              style: TextStyle(color: NeuralTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInState {
  const _SignedInState({
    required this.user,
    required this.sessions,
    required this.stats,
    required this.leaderboardUsers,
  });

  final AppUser? user;
  final List<GameSession> sessions;
  final PlayerStats stats;
  final List<AppUser> leaderboardUsers;
}

class _MissingClerkConfigurationApp extends StatelessWidget {
  const _MissingClerkConfigurationApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF08111F),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 520),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF132238),
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Missing Clerk configuration',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Run the app with --dart-define=CLERK_PUBLISHABLE_KEY=pk_... or enable local repositories with --dart-define=USE_LOCAL_DATA=true.',
                          style: TextStyle(
                            color: Color(0xFFD2D8E2),
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AuthMode { signIn, signUp }

enum _ClerkAuthMode { signIn, signUp }

class _ClerkAuthScreen extends StatefulWidget {
  const _ClerkAuthScreen();

  @override
  State<_ClerkAuthScreen> createState() => _ClerkAuthScreenState();
}

class _ClerkAuthScreenState extends State<_ClerkAuthScreen> {
  final TextEditingController _signInIdentifierController =
      TextEditingController();
  final TextEditingController _signInPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _signUpPasswordController =
      TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _verificationCodeController =
      TextEditingController();

  _ClerkAuthMode _mode = _ClerkAuthMode.signIn;
  bool _isSubmitting = false;
  bool _awaitingEmailVerification = false;
  bool _acceptedTerms = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _signInIdentifierController.dispose();
    _signInPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _signUpEmailController.dispose();
    _phoneController.dispose();
    _signUpPasswordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _switchMode(_ClerkAuthMode mode) async {
    if (_mode == mode) {
      return;
    }

    setState(() {
      _mode = mode;
      _awaitingEmailVerification = false;
      _errorMessage = null;
      _infoMessage = null;
      _verificationCodeController.clear();
    });

    await ClerkAuth.of(context, listen: false).resetClient();
  }

  void _recordClerkError(clerk.ClerkError error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = _formatClerkError(error);
      _infoMessage = null;
    });
  }

  String _formatClerkError(clerk.ClerkError error) {
    final String collectionMessage = error.errors?.errorMessage.trim() ?? '';
    if (collectionMessage.isNotEmpty && !collectionMessage.contains('{arg}')) {
      return collectionMessage;
    }

    final String argument = error.argument?.trim() ?? '';
    if (argument.isNotEmpty) {
      return argument;
    }

    final String renderedMessage = error.toString().trim();
    if (renderedMessage.isNotEmpty && !renderedMessage.contains('{arg}')) {
      return renderedMessage;
    }

    final String rawMessage = error.message.trim();
    if (rawMessage.isNotEmpty && !rawMessage.contains('{arg}')) {
      return rawMessage;
    }

    return 'The authentication request failed. Review the form and try again.';
  }

  bool _isAttributeEnabled(
    ClerkAuthState authState,
    clerk.UserAttribute attribute,
  ) {
    return authState.env.user.attributes[attribute]?.isEnabled ?? false;
  }

  bool _isAttributeRequired(
    ClerkAuthState authState,
    clerk.UserAttribute attribute,
  ) {
    return authState.env.user.attributes[attribute]?.isRequired ?? false;
  }

  bool _supportsGoogle(ClerkAuthState authState) {
    return authState.env.socialConnections.any(
      (connection) =>
          connection.strategy.provider == clerk.Strategy.oauthGoogle.provider,
    );
  }

  bool _emailNeedsVerification(ClerkAuthState authState) {
    final clerk.SignUp? signUp = authState.signUp;
    return signUp?.unverified(clerk.Field.emailAddress) == true ||
        signUp?.awaiting(clerk.Field.emailAddress) == true;
  }

  String _verificationDestination(ClerkAuthState authState) {
    final String email = _signUpEmailController.text.trim();
    if (email.isNotEmpty) {
      return email;
    }
    return authState.signUp?.emailAddress ?? 'your inbox';
  }

  String _passwordHint(clerk.PasswordSettings settings) {
    final List<String> parts = <String>[
      if (settings.minLength > 0) '${settings.minLength}+ characters',
      if (settings.requireUppercase) '1 uppercase',
      if (settings.requireLowercase) '1 lowercase',
      if (settings.requireNumbers) '1 number',
      if (settings.requireSpecialChar) '1 symbol',
    ];
    return parts.isEmpty ? 'Use a strong password.' : parts.join('  •  ');
  }

  String? _validateSignUp(ClerkAuthState authState) {
    if (_isAttributeRequired(authState, clerk.UserAttribute.firstName) &&
        _firstNameController.text.trim().isEmpty) {
      return 'First name is required.';
    }
    if (_isAttributeRequired(authState, clerk.UserAttribute.lastName) &&
        _lastNameController.text.trim().isEmpty) {
      return 'Last name is required.';
    }
    if (_isAttributeRequired(authState, clerk.UserAttribute.username) &&
        _usernameController.text.trim().isEmpty) {
      return 'Username is required.';
    }
    if (_isAttributeRequired(authState, clerk.UserAttribute.emailAddress) &&
        _signUpEmailController.text.trim().isEmpty) {
      return 'Email address is required.';
    }
    if (_isAttributeRequired(authState, clerk.UserAttribute.phoneNumber) &&
        _phoneController.text.trim().isEmpty) {
      return 'Phone number is required.';
    }
    if (_isAttributeEnabled(authState, clerk.UserAttribute.password)) {
      final String? passwordError = authState.checkPassword(
        _signUpPasswordController.text,
        _confirmPasswordController.text,
        context,
      );
      if (passwordError != null) {
        return passwordError;
      }
    }
    if (authState.env.user.signUp.legalConsentEnabled && !_acceptedTerms) {
      return 'You need to accept the terms to create an account.';
    }
    return null;
  }

  Future<void> _submitSignIn(ClerkAuthState authState) async {
    final String identifier = _signInIdentifierController.text.trim();
    final String password = _signInPasswordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your email or username and password.';
        _infoMessage = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await authState.safelyCall(
        context,
        () => authState.attemptSignIn(
          strategy: clerk.Strategy.password,
          identifier: identifier,
          password: password,
        ),
        onError: _recordClerkError,
      );

      if (!mounted || authState.user != null) {
        return;
      }

      if (authState.signIn?.needsFactor == true &&
          authState.signIn?.canUsePassword == false) {
        setState(() {
          _errorMessage =
              'This account needs a different sign-in factor than password.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _prepareEmailVerification(
    ClerkAuthState authState, {
    bool resend = false,
  }) async {
    if (authState.env.supportsEmailCode) {
      await authState.safelyCall(
        context,
        () => authState.attemptSignUp(strategy: clerk.Strategy.emailCode),
        onError: _recordClerkError,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _awaitingEmailVerification = true;
        _errorMessage = null;
        _infoMessage = resend
            ? 'A fresh verification code was sent to ${_verificationDestination(authState)}.'
            : 'Enter the six-digit code sent to ${_verificationDestination(authState)}.';
      });
      return;
    }

    if (authState.env.supportsEmailLink) {
      final Uri? redirectUri = authState.emailVerificationRedirectUri(context);
      await authState.safelyCall(
        context,
        () => authState.attemptSignUp(
          strategy: clerk.Strategy.emailLink,
          redirectUrl: redirectUri?.toString(),
        ),
        onError: _recordClerkError,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _awaitingEmailVerification = true;
        _errorMessage = null;
        _infoMessage =
            'Check ${_verificationDestination(authState)} for the secure verification link.';
      });
      return;
    }

    setState(() {
      _awaitingEmailVerification = true;
      _errorMessage = null;
      _infoMessage = 'Verify your email to finish creating your account.';
    });
  }

  Future<void> _submitSignUp(ClerkAuthState authState) async {
    final String? validationError = _validateSignUp(authState);
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
        _infoMessage = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await authState.safelyCall(
        context,
        () => authState.attemptSignUp(
          strategy: clerk.Strategy.password,
          firstName:
              _isAttributeEnabled(authState, clerk.UserAttribute.firstName)
              ? _firstNameController.text.trim()
              : null,
          lastName: _isAttributeEnabled(authState, clerk.UserAttribute.lastName)
              ? _lastNameController.text.trim()
              : null,
          username: _isAttributeEnabled(authState, clerk.UserAttribute.username)
              ? _usernameController.text.trim()
              : null,
          emailAddress:
              _isAttributeEnabled(authState, clerk.UserAttribute.emailAddress)
              ? _signUpEmailController.text.trim()
              : null,
          phoneNumber:
              _isAttributeEnabled(authState, clerk.UserAttribute.phoneNumber)
              ? _phoneController.text.trim()
              : null,
          password: _isAttributeEnabled(authState, clerk.UserAttribute.password)
              ? _signUpPasswordController.text
              : null,
          passwordConfirmation:
              _isAttributeEnabled(authState, clerk.UserAttribute.password)
              ? _confirmPasswordController.text
              : null,
          legalAccepted: authState.env.user.signUp.legalConsentEnabled
              ? _acceptedTerms
              : null,
        ),
        onError: _recordClerkError,
      );

      if (!mounted || authState.user != null) {
        return;
      }

      if (_emailNeedsVerification(authState)) {
        await _prepareEmailVerification(authState);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitVerificationCode(ClerkAuthState authState) async {
    final String code = _verificationCodeController.text.trim();
    if (code.length != clerk.Strategy.numericalCodeLength) {
      setState(() {
        _errorMessage = 'Enter the six-digit code from your email.';
        _infoMessage = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await authState.safelyCall(
        context,
        () => authState.attemptSignUp(
          strategy: clerk.Strategy.emailCode,
          code: code,
        ),
        onError: _recordClerkError,
      );

      if (!mounted || authState.user != null) {
        return;
      }

      if (authState.signUp?.isTransferable == true) {
        await authState.safelyCall(
          context,
          authState.transfer,
          onError: _recordClerkError,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitSocial(ClerkAuthState authState) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      if (_mode == _ClerkAuthMode.signIn) {
        await authState.ssoSignIn(
          context,
          clerk.Strategy.oauthGoogle,
          onError: _recordClerkError,
        );
      } else {
        await authState.ssoSignUp(
          context,
          clerk.Strategy.oauthGoogle,
          onError: _recordClerkError,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSignInForm(ClerkAuthState authState) {
    return Column(
      key: const ValueKey<String>('sign-in-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AuthTextField(
          controller: _signInIdentifierController,
          label: 'Email or username',
          hint: 'you@example.com',
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _AuthTextField(
          controller: _signInPasswordController,
          label: 'Password',
          hint: 'Enter your password',
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitSignIn(authState),
        ),
        const SizedBox(height: 24),
        _AuthPrimaryButton(
          label: _isSubmitting ? 'Signing in...' : 'Sign in',
          onPressed: _isSubmitting ? null : () => _submitSignIn(authState),
        ),
      ],
    );
  }

  Widget _buildSignUpForm(ClerkAuthState authState) {
    final clerk.PasswordSettings passwordSettings =
        authState.env.user.passwordSettings;

    return Column(
      key: const ValueKey<String>('sign-up-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isAttributeEnabled(authState, clerk.UserAttribute.firstName) ||
            _isAttributeEnabled(authState, clerk.UserAttribute.lastName))
          Row(
            children: [
              if (_isAttributeEnabled(authState, clerk.UserAttribute.firstName))
                Expanded(
                  child: _AuthTextField(
                    controller: _firstNameController,
                    label: 'First name',
                    hint: 'Anas',
                    textInputAction: TextInputAction.next,
                  ),
                ),
              if (_isAttributeEnabled(
                    authState,
                    clerk.UserAttribute.firstName,
                  ) &&
                  _isAttributeEnabled(authState, clerk.UserAttribute.lastName))
                const SizedBox(width: 14),
              if (_isAttributeEnabled(authState, clerk.UserAttribute.lastName))
                Expanded(
                  child: _AuthTextField(
                    controller: _lastNameController,
                    label: 'Last name',
                    hint: 'ali',
                    textInputAction: TextInputAction.next,
                  ),
                ),
            ],
          ),
        if (_isAttributeEnabled(authState, clerk.UserAttribute.firstName) ||
            _isAttributeEnabled(authState, clerk.UserAttribute.lastName))
          const SizedBox(height: 16),
        if (_isAttributeEnabled(authState, clerk.UserAttribute.username)) ...[
          _AuthTextField(
            controller: _usernameController,
            label: 'Username',
            hint: 'simonchamp',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
        ],
        if (_isAttributeEnabled(
          authState,
          clerk.UserAttribute.emailAddress,
        )) ...[
          _AuthTextField(
            controller: _signUpEmailController,
            label: 'Email address',
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
        ],
        if (_isAttributeEnabled(
          authState,
          clerk.UserAttribute.phoneNumber,
        )) ...[
          _AuthTextField(
            controller: _phoneController,
            label: 'Phone number',
            hint: '+966 5X XXX XXXX',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
        ],
        if (_isAttributeEnabled(authState, clerk.UserAttribute.password)) ...[
          _AuthTextField(
            controller: _signUpPasswordController,
            label: 'Password',
            hint: 'Create a password',
            obscureText: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          Text(
            _passwordHint(passwordSettings),
            style: const TextStyle(
              color: NeuralTheme.textDim,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          _AuthTextField(
            controller: _confirmPasswordController,
            label: 'Confirm password',
            hint: 'Repeat your password',
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitSignUp(authState),
          ),
          const SizedBox(height: 18),
        ],
        if (authState.env.user.signUp.legalConsentEnabled) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: _acceptedTerms
                        ? NeuralTheme.primarySoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _acceptedTerms
                          ? NeuralTheme.primarySoft
                          : NeuralTheme.outline.withValues(alpha: 0.65),
                    ),
                  ),
                  child: _acceptedTerms
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Color(0xFF071014),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'I agree to the terms and privacy policy for this workspace.',
                    style: TextStyle(
                      color: NeuralTheme.textMuted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        _AuthPrimaryButton(
          label: _isSubmitting ? 'Creating account...' : 'Create account',
          onPressed: _isSubmitting ? null : () => _submitSignUp(authState),
        ),
      ],
    );
  }

  Widget _buildVerificationForm(ClerkAuthState authState) {
    return Column(
      key: const ValueKey<String>('verify-email-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NeuralTheme.surfaceHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: NeuralTheme.outline.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: NeuralTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.mark_email_read_rounded,
                  color: NeuralTheme.primarySoft,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'We sent a verification code to ${_verificationDestination(authState)}.',
                  style: const TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (authState.env.supportsEmailCode) ...[
          _AuthTextField(
            controller: _verificationCodeController,
            label: 'Verification code',
            hint: '123456',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitVerificationCode(authState),
          ),
          const SizedBox(height: 20),
          _AuthPrimaryButton(
            label: _isSubmitting ? 'Verifying...' : 'Verify email',
            onPressed: _isSubmitting
                ? null
                : () => _submitVerificationCode(authState),
          ),
          const SizedBox(height: 12),
          _AuthSecondaryButton(
            label: 'Send a new code',
            onPressed: _isSubmitting
                ? null
                : () => _prepareEmailVerification(authState, resend: true),
          ),
        ] else ...[
          _AuthSecondaryButton(
            label: 'Send verification link again',
            onPressed: _isSubmitting
                ? null
                : () => _prepareEmailVerification(authState, resend: true),
          ),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() {
                    _awaitingEmailVerification = false;
                    _errorMessage = null;
                    _infoMessage = null;
                    _verificationCodeController.clear();
                  });
                  await ClerkAuth.of(context, listen: false).resetClient();
                },
          style: TextButton.styleFrom(
            foregroundColor: NeuralTheme.textMuted,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Start over'),
        ),
      ],
    );
  }

  Widget _buildAuthPanel(BuildContext context, ClerkAuthState authState) {
    final clerk.DisplayConfig display = ClerkAuth.displayConfigOf(context);
    final bool isSignUp = _mode == _ClerkAuthMode.signUp;
    final bool showGoogle = _supportsGoogle(authState);
    final bool showVerification = _awaitingEmailVerification && isSignUp;
    final String appName = display.applicationName.isEmpty
        ? 'Simon Says'
        : display.applicationName;
    final String title = showVerification
        ? 'Verify email'
        : isSignUp
        ? 'Create account'
        : 'Sign in';
    final String subtitle = showVerification
        ? 'Enter the code from your email.'
        : isSignUp
        ? 'Use email and password.'
        : 'Use your account details.';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: NeuralTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: NeuralTheme.outline.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: NeuralTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  color: NeuralTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  appName,
                  style: const TextStyle(
                    color: NeuralTheme.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          if (!showVerification) ...[
            const SizedBox(height: 20),
            _AuthModeToggle(
              mode: _mode,
              onChanged: _isSubmitting ? null : _switchMode,
            ),
          ],
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: NeuralTheme.text,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: NeuralTheme.textMuted,
              fontSize: 14,
            ),
          ),
          if (showGoogle) ...[
            const SizedBox(height: 18),
            _AuthSocialButton(
              label: isSignUp ? 'Continue with Google' : 'Sign in with Google',
              onPressed: _isSubmitting ? null : () => _submitSocial(authState),
            ),
            const SizedBox(height: 18),
            const _AuthDivider(label: 'or'),
          ] else ...[
            const SizedBox(height: 18),
          ],
          if (_errorMessage != null || _infoMessage != null) ...[
            _AuthMessageBanner(
              errorMessage: _errorMessage,
              infoMessage: _infoMessage,
            ),
            const SizedBox(height: 18),
          ],
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: showVerification
                ? _buildVerificationForm(authState)
                : isSignUp
                ? _buildSignUpForm(authState)
                : _buildSignInForm(authState),
          ),
          const SizedBox(height: 18),
          if (display.branded || display.showDevmodeWarning)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (display.branded)
                  const _AuthFooterChip(
                    icon: Icons.verified_user_rounded,
                    label: 'Secured by Clerk',
                  ),
                if (display.showDevmodeWarning)
                  const _AuthFooterChip(
                    icon: Icons.developer_mode_rounded,
                    label: 'Development mode',
                    warning: true,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClerkAuthBuilder(
      builder: (context, authState) {
        return Scaffold(
          backgroundColor: NeuralTheme.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildAuthPanel(context, authState),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.mode, required this.onChanged});

  final _ClerkAuthMode mode;
  final ValueChanged<_ClerkAuthMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthToggleButton(
              label: 'Sign in',
              selected: mode == _ClerkAuthMode.signIn,
              onPressed: onChanged == null
                  ? null
                  : () => onChanged!(_ClerkAuthMode.signIn),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AuthToggleButton(
              label: 'Create account',
              selected: mode == _ClerkAuthMode.signUp,
              onPressed: onChanged == null
                  ? null
                  : () => onChanged!(_ClerkAuthMode.signUp),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthToggleButton extends StatelessWidget {
  const _AuthToggleButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        foregroundColor: selected ? Colors.white : NeuralTheme.textMuted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NeuralTheme.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: NeuralTheme.textDim,
              fontSize: 15,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: NeuralTheme.outline.withValues(alpha: 0.28),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: NeuralTheme.outline.withValues(alpha: 0.28),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: NeuralTheme.primary.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthPrimaryButton extends StatelessWidget {
  const _AuthPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: NeuralTheme.primarySoft.withValues(alpha: 0.98),
        foregroundColor: const Color(0xFF061015),
        disabledBackgroundColor: NeuralTheme.primarySoft.withValues(
          alpha: 0.35,
        ),
        disabledForegroundColor: const Color(
          0xFF061015,
        ).withValues(alpha: 0.55),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AuthSecondaryButton extends StatelessWidget {
  const _AuthSecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AuthSocialButton extends StatelessWidget {
  const _AuthSocialButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        backgroundColor: Colors.white.withValues(alpha: 0.035),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              'G',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: NeuralTheme.textDim,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _AuthMessageBanner extends StatelessWidget {
  const _AuthMessageBanner({this.errorMessage, this.infoMessage});

  final String? errorMessage;
  final String? infoMessage;

  @override
  Widget build(BuildContext context) {
    final bool isError = errorMessage != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? NeuralTheme.errorContainer.withValues(alpha: 0.30)
            : NeuralTheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError
              ? NeuralTheme.error.withValues(alpha: 0.28)
              : NeuralTheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: isError ? NeuralTheme.error : NeuralTheme.primarySoft,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage ?? infoMessage ?? '',
              style: TextStyle(
                color: isError ? NeuralTheme.error : NeuralTheme.textMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthFooterChip extends StatelessWidget {
  const _AuthFooterChip({
    required this.icon,
    required this.label,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final Color accent = warning
        ? const Color(0xFFFFB649)
        : NeuralTheme.textDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalAuthScreen extends StatefulWidget {
  const _LocalAuthScreen({
    required this.authRepository,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final Future<void> Function(AppUser user) onAuthenticated;

  @override
  State<_LocalAuthScreen> createState() => _LocalAuthScreenState();
}

class _LocalAuthScreenState extends State<_LocalAuthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final AppUser user = switch (_mode) {
        _AuthMode.signIn => await widget.authRepository.signIn(
          username: _usernameController.text,
          password: _passwordController.text,
        ),
        _AuthMode.signUp => await widget.authRepository.signUp(
          username: _usernameController.text,
          password: _passwordController.text,
        ),
      };
      if (!mounted) {
        return;
      }
      await widget.onAuthenticated(user);
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeuralTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: NeuralTheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: NeuralTheme.outline.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: NeuralTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.grid_view_rounded,
                              color: NeuralTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Simon Says',
                              style: TextStyle(
                                color: NeuralTheme.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _AuthModeButton(
                              label: 'SIGN IN',
                              selected: _mode == _AuthMode.signIn,
                              onTap: () {
                                setState(() {
                                  _mode = _AuthMode.signIn;
                                  _errorMessage = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _AuthModeButton(
                              label: 'SIGN UP',
                              selected: _mode == _AuthMode.signUp,
                              onTap: () {
                                setState(() {
                                  _mode = _AuthMode.signUp;
                                  _errorMessage = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _mode == _AuthMode.signIn ? 'Sign in' : 'Create account',
                        style: const TextStyle(
                          color: NeuralTheme.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Use username and password.',
                        style: TextStyle(
                          color: NeuralTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _usernameController,
                        enabled: !_isSubmitting,
                        textInputAction: TextInputAction.next,
                        decoration: _authInputDecoration(
                          label: 'Username',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 3) {
                            return 'Use at least 3 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isSubmitting,
                        obscureText: true,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: _authInputDecoration(
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.length < 4) {
                            return 'Use at least 4 characters.';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: NeuralTheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: NeuralTheme.primary,
                            foregroundColor: NeuralTheme.onAccent,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : Text(
                                  _mode == _AuthMode.signIn
                                      ? 'SIGN IN'
                                      : 'CREATE ACCOUNT',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _authInputDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: NeuralTheme.surfaceHighest.withValues(alpha: 0.42),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: NeuralTheme.outline.withValues(alpha: 0.2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: NeuralTheme.outline.withValues(alpha: 0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: NeuralTheme.primary.withValues(alpha: 0.45),
      ),
    ),
  );
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? NeuralTheme.primary.withValues(alpha: 0.12)
              : NeuralTheme.surfaceHighest.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? NeuralTheme.primary.withValues(alpha: 0.34)
                : NeuralTheme.outline.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? NeuralTheme.primarySoft : NeuralTheme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

@immutable
class AppThemePalette {
  const AppThemePalette({
    required this.label,
    required this.primary,
    required this.primarySoft,
    required this.secondary,
    required this.secondarySoft,
    required this.tertiary,
    required this.primaryGlow,
    required this.secondaryGlow,
    required this.background,
    required this.backgroundBottom,
    required this.onAccent,
  });

  final String label;
  final Color primary;
  final Color primarySoft;
  final Color secondary;
  final Color secondarySoft;
  final Color tertiary;
  final Color primaryGlow;
  final Color secondaryGlow;
  final Color background;
  final Color backgroundBottom;
  final Color onAccent;
}

class NeuralTheme {
  static const Color surface = Color(0xFF1C1B1B);
  static const Color surfaceHigh = Color(0xFF2A2A2A);
  static const Color surfaceHighest = Color(0xFF353534);
  static const Color outline = Color(0xFF3B494C);
  static const Color text = Color(0xFFE5E2E1);
  static const Color textMuted = Color(0xFFBAC9CC);
  static const Color textDim = Color(0xFF849396);
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);

  static const Map<AppThemeProfile, AppThemePalette> _palettes =
      <AppThemeProfile, AppThemePalette>{
        AppThemeProfile.neuralBlue: AppThemePalette(
          label: 'Neural Blue',
          primary: Color(0xFF00E5FF),
          primarySoft: Color(0xFFC3F5FF),
          secondary: Color(0xFF7C4DFF),
          secondarySoft: Color(0xFFCDBDFF),
          tertiary: Color(0xFFFEC931),
          primaryGlow: Color(0x3300E5FF),
          secondaryGlow: Color(0x267C4DFF),
          background: Color(0xFF131313),
          backgroundBottom: Color(0xFF0E0E0E),
          onAccent: Color(0xFF00363D),
        ),
        AppThemeProfile.emberGlow: AppThemePalette(
          label: 'Ember Glow',
          primary: Color(0xFFFF8A65),
          primarySoft: Color(0xFFFFD2C3),
          secondary: Color(0xFFFFC857),
          secondarySoft: Color(0xFFFFE4A5),
          tertiary: Color(0xFF7EE0C5),
          primaryGlow: Color(0x33FF8A65),
          secondaryGlow: Color(0x29FFC857),
          background: Color(0xFF17110F),
          backgroundBottom: Color(0xFF120E0D),
          onAccent: Color(0xFF4A1906),
        ),
        AppThemeProfile.mintCircuit: AppThemePalette(
          label: 'Mint Circuit',
          primary: Color(0xFF5BF2C5),
          primarySoft: Color(0xFFD1FFF1),
          secondary: Color(0xFF4FC3F7),
          secondarySoft: Color(0xFFCBEFFF),
          tertiary: Color(0xFFFFB86C),
          primaryGlow: Color(0x305BF2C5),
          secondaryGlow: Color(0x264FC3F7),
          background: Color(0xFF101716),
          backgroundBottom: Color(0xFF0C1110),
          onAccent: Color(0xFF00382C),
        ),
      };

  static AppThemeProfile _activeProfile = AppThemeProfile.neuralBlue;

  static void activate(AppThemeProfile profile) {
    _activeProfile = profile;
  }

  static AppThemePalette paletteFor(AppThemeProfile profile) {
    return _palettes[profile]!;
  }

  static AppThemePalette get palette => _palettes[_activeProfile]!;

  static Color get primary => palette.primary;
  static Color get primarySoft => palette.primarySoft;
  static Color get secondary => palette.secondary;
  static Color get secondarySoft => palette.secondarySoft;
  static Color get tertiary => palette.tertiary;
  static Color get primaryGlow => palette.primaryGlow;
  static Color get secondaryGlow => palette.secondaryGlow;
  static Color get background => palette.background;
  static Color get backgroundBottom => palette.backgroundBottom;
  static Color get onAccent => palette.onAccent;

  static ThemeData get materialTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surface,
        onPrimary: onAccent,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.6,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
        ),
      ),
    );
  }
}

const double _navBarBaseHeight = 88;
const double _mainMenuDesignWidth = 560;
const double _mainMenuDesignHeight = 680;
const double _statsScreenDesignWidth = 560;
const double _gameScreenDesignWidth = 560;
const double _gameScreenDesignHeight = 760;

final _FullscreenUiObserver _fullscreenObserver = _FullscreenUiObserver();

Future<void> _configureFullscreenUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
}

Future<void> _configureEdgeToEdgeUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
}

class _FullscreenUiObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _configureFullscreenUi();
    }
  }
}

enum GameMode {
  focus(
    label: 'Focus Mode',
    menuTitle: 'Easy mode',
    subtitle: '4 Tiles | Relaxed Speed',
    scoreLabel: 'FOCUS MODE',
    gridSize: 2,
    icon: Icons.auto_awesome_motion_rounded,
    flashDuration: Duration(milliseconds: 560),
    flashGap: Duration(milliseconds: 180),
    roundLeadIn: Duration(milliseconds: 420),
    pointsPerStep: 140,
    roundBonus: 120,
  ),
  overdrive(
    label: 'Overdrive Mode',
    menuTitle: 'Hard Mode',
    subtitle: '9 Tiles | Rapid Sequence',
    scoreLabel: 'OVERDRIVE',
    gridSize: 3,
    icon: Icons.bolt_rounded,
    flashDuration: Duration(milliseconds: 300),
    flashGap: Duration(milliseconds: 90),
    roundLeadIn: Duration(milliseconds: 240),
    pointsPerStep: 260,
    roundBonus: 220,
    baseTapTimeout: Duration(milliseconds: 1800),
  );

  const GameMode({
    required this.label,
    required this.menuTitle,
    required this.subtitle,
    required this.scoreLabel,
    required this.gridSize,
    required this.icon,
    required this.flashDuration,
    required this.flashGap,
    required this.roundLeadIn,
    required this.pointsPerStep,
    required this.roundBonus,
    this.baseTapTimeout,
  });

  final String label;
  final String menuTitle;
  final String subtitle;
  final String scoreLabel;
  final int gridSize;
  final IconData icon;
  final Duration flashDuration;
  final Duration flashGap;
  final Duration roundLeadIn;
  final int pointsPerStep;
  final int roundBonus;
  final Duration? baseTapTimeout;

  Color get accent =>
      this == GameMode.focus ? NeuralTheme.primary : NeuralTheme.secondary;
}

enum GamePhase { booting, showing, input, roundClear, failed }

extension on GameMode {
  GameModeKey get statsKey {
    switch (this) {
      case GameMode.focus:
        return GameModeKey.focus;
      case GameMode.overdrive:
        return GameModeKey.overdrive;
    }
  }
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({
    super.key,
    required this.currentUser,
    required this.playerStats,
    required this.settings,
    required this.onSessionCompleted,
    required this.onOpenSettings,
  });

  final ValueNotifier<AppUser?> currentUser;
  final ValueNotifier<PlayerStats> playerStats;
  final ValueNotifier<NeuralSettings> settings;
  final Future<void> Function(GameSession session) onSessionCompleted;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double bottomNavHeight = 74 + math.max(12, bottomInset);
    return ValueListenableBuilder<NeuralSettings>(
      valueListenable: settings,
      builder: (context, currentSettings, _) {
        NeuralTheme.activate(currentSettings.appTheme);
        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [NeuralTheme.background, NeuralTheme.backgroundBottom],
              ),
            ),
            child: Stack(
              children: [
                _BackgroundEffects(),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      NeuralTopBar(onAction: onOpenSettings),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            8,
                            24,
                            bottomNavHeight,
                          ),
                          child: _ScaleToFit(
                            designWidth: _mainMenuDesignWidth,
                            designHeight: _mainMenuDesignHeight,
                            child: Column(
                              children: [
                                const _HeroLogo(),
                                const SizedBox(height: 16),
                                ValueListenableBuilder<AppUser?>(
                                  valueListenable: currentUser,
                                  builder: (context, user, _) {
                                    if (user == null) {
                                      return const SizedBox.shrink();
                                    }

                                    return _SignedInProfilePill(user: user);
                                  },
                                ),
                                const SizedBox(height: 28),
                                _ModeButton(
                                  mode: GameMode.focus,
                                  onTap: () =>
                                      _openGame(context, GameMode.focus),
                                ),
                                const SizedBox(height: 16),
                                _ModeButton(
                                  mode: GameMode.overdrive,
                                  onTap: () =>
                                      _openGame(context, GameMode.overdrive),
                                ),
                                const Spacer(),
                                Text(
                                  'V1.0.0',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: NeuralTheme.textDim.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openGame(BuildContext context, GameMode mode) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: _screenTransitionDuration(settings.value),
        reverseTransitionDuration: _screenTransitionDuration(settings.value),
        pageBuilder: (context, animation, secondaryAnimation) => GameScreen(
          mode: mode,
          initialBestScore:
              playerStats.value.bestScoreByMode[mode.statsKey] ?? 0,
          settings: settings.value,
          onSessionCompleted: onSessionCompleted,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final Animation<double> curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final Animation<Offset> slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curvedAnimation);
          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
      ),
    );
  }

  Duration _screenTransitionDuration(NeuralSettings settings) {
    return settings.tuneDuration(
      const Duration(milliseconds: 220),
      reducedFactor: 0.55,
      minMilliseconds: 110,
    );
  }
}

class _SignedInProfilePill extends StatelessWidget {
  const _SignedInProfilePill({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NeuralTheme.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_rounded,
            color: NeuralTheme.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            'SIGNED IN AS ${user.username.toUpperCase()}',
            style: const TextStyle(
              color: NeuralTheme.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLogo extends StatelessWidget {
  const _HeroLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -3,
              right: -4,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: NeuralTheme.secondary,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: NeuralTheme.secondaryGlow.withValues(alpha: 0.65),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
            Icon(
              Icons.psychology_alt_rounded,
              size: 84,
              color: NeuralTheme.primary,
              shadows: [
                Shadow(
                  color: NeuralTheme.primaryGlow.withValues(alpha: 0.7),
                  blurRadius: 24,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'NEURAL\nRECALL',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: NeuralTheme.primary,
            fontSize: 46,
            height: 0.92,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -2.2,
            shadows: [
              Shadow(
                color: NeuralTheme.primaryGlow.withValues(alpha: 0.7),
                blurRadius: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({
    super.key,
    required this.currentUser,
    required this.playerStats,
    required this.sessions,
    required this.leaderboardUsers,
    required this.settings,
  });

  final ValueNotifier<AppUser?> currentUser;
  final ValueNotifier<PlayerStats> playerStats;
  final ValueNotifier<List<GameSession>> sessions;
  final ValueNotifier<List<AppUser>> leaderboardUsers;
  final ValueNotifier<NeuralSettings> settings;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double bottomNavHeight = _navBarBaseHeight + bottomInset;
    return ValueListenableBuilder<NeuralSettings>(
      valueListenable: settings,
      builder: (context, currentSettings, _) {
        NeuralTheme.activate(currentSettings.appTheme);
        return DecoratedBox(
          decoration: BoxDecoration(color: NeuralTheme.background),
          child: Stack(
            children: [
              _BackgroundEffects(),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    NeuralTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          8,
                          24,
                          bottomNavHeight + 18,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _statsScreenDesignWidth,
                            ),
                            child: ValueListenableBuilder<PlayerStats>(
                              valueListenable: playerStats,
                              builder: (context, stats, _) {
                                return ValueListenableBuilder<
                                  List<GameSession>
                                >(
                                  valueListenable: sessions,
                                  builder: (context, savedSessions, _) {
                                    return ValueListenableBuilder<
                                      List<AppUser>
                                    >(
                                      valueListenable: leaderboardUsers,
                                      builder: (context, rankedUsers, _) {
                                        return _StatsDashboard(
                                          currentUser: currentUser.value,
                                          stats: stats,
                                          sessions: savedSessions,
                                          leaderboardUsers: rankedUsers,
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.currentUser,
    required this.playerStats,
    required this.settings,
    required this.onSettingsChanged,
    required this.onSignOut,
  });

  final ValueNotifier<AppUser?> currentUser;
  final ValueNotifier<PlayerStats> playerStats;
  final ValueNotifier<NeuralSettings> settings;
  final ValueChanged<NeuralSettings> onSettingsChanged;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double bottomNavHeight = _navBarBaseHeight + bottomInset;
    return ValueListenableBuilder<NeuralSettings>(
      valueListenable: settings,
      builder: (context, currentSettings, _) {
        NeuralTheme.activate(currentSettings.appTheme);
        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(color: NeuralTheme.background),
            child: Stack(
              children: [
                _BackgroundEffects(),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      NeuralTopBar(),
                      Expanded(
                        child: ValueListenableBuilder<PlayerStats>(
                          valueListenable: playerStats,
                          builder: (context, currentStats, child) {
                            return SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                24,
                                8,
                                24,
                                bottomNavHeight + 18,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: _statsScreenDesignWidth,
                                  ),
                                  child: _SettingsDashboard(
                                    currentUser: currentUser.value,
                                    bestStreak: currentStats.bestStreak,
                                    settings: currentSettings,
                                    onSettingsChanged: onSettingsChanged,
                                    onSignOut: onSignOut,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsDashboard extends StatelessWidget {
  const _SettingsDashboard({
    required this.currentUser,
    required this.bestStreak,
    required this.settings,
    required this.onSettingsChanged,
    required this.onSignOut,
  });

  final AppUser? currentUser;
  final int bestStreak;
  final NeuralSettings settings;
  final ValueChanged<NeuralSettings> onSettingsChanged;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'APP SETTINGS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: NeuralTheme.textDim.withValues(alpha: 0.52),
          ),
        ),
        const SizedBox(height: 18),
        _SettingsHeroCard(bestStreak: bestStreak, settings: settings),
        const SizedBox(height: 22),
        _LocalProfileCard(currentUser: currentUser, onSignOut: onSignOut),
        const SizedBox(height: 22),
        const _SettingsSectionTitle(
          label: 'APPEARANCE',
          subtitle: 'Pick the app palette and visual intensity.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AppThemeProfile.values.map((themeProfile) {
            final AppThemePalette palette = NeuralTheme.paletteFor(
              themeProfile,
            );
            return _ThemeProfileCard(
              profile: themeProfile,
              palette: palette,
              selected: settings.appTheme == themeProfile,
              onTap: () {
                onSettingsChanged(settings.copyWith(appTheme: themeProfile));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        _SettingsToggleCard(
          icon: Icons.motion_photos_off_rounded,
          title: 'Reduced Motion',
          description:
              'Shortens flashes and transitions for a calmer, snappier board.',
          value: settings.reducedMotion,
          accent: NeuralTheme.secondarySoft,
          onChanged: (enabled) {
            onSettingsChanged(settings.copyWith(reducedMotion: enabled));
          },
        ),
        const SizedBox(height: 24),
        const _SettingsSectionTitle(
          label: 'GAMEPLAY',
          subtitle: 'Change timing and helper behavior inside active runs.',
        ),
        const SizedBox(height: 14),
        _SettingsSliderCard(
          icon: Icons.speed_rounded,
          title: 'Sequence Pace',
          description:
              'Controls how fast flashes and round transitions feel across both modes.',
          value: settings.sequenceSpeed,
          min: 0.85,
          max: 1.20,
          divisions: 7,
          accent: NeuralTheme.primary,
          valueLabel:
              '${settings.paceLabel} ${_percent(settings.sequenceSpeed)}',
          onChanged: (value) {
            onSettingsChanged(settings.copyWith(sequenceSpeed: value));
          },
        ),
        const SizedBox(height: 14),
        _SettingsSliderCard(
          icon: Icons.timer_outlined,
          title: 'Overdrive Reaction Window',
          description:
              'Widens or tightens the tap timer only for overdrive rounds.',
          value: settings.overdriveWindowScale,
          min: 0.85,
          max: 1.25,
          divisions: 8,
          accent: NeuralTheme.secondary,
          valueLabel:
              '${settings.overdriveLabel} ${_percent(settings.overdriveWindowScale)}',
          onChanged: (value) {
            onSettingsChanged(settings.copyWith(overdriveWindowScale: value));
          },
        ),
        const SizedBox(height: 14),
        _SettingsToggleCard(
          icon: Icons.tips_and_updates_rounded,
          title: 'Training Hints',
          description:
              'Keeps the live hint card visible under the board while you play.',
          value: settings.trainingHintsEnabled,
          accent: NeuralTheme.primary,
          onChanged: (enabled) {
            onSettingsChanged(settings.copyWith(trainingHintsEnabled: enabled));
          },
        ),
        const SizedBox(height: 14),
        _SettingsToggleCard(
          icon: Icons.restart_alt_rounded,
          title: 'Confirm Reset',
          description:
              'Requires confirmation before wiping the current run from the game screen.',
          value: settings.confirmResetEnabled,
          accent: NeuralTheme.tertiary,
          onChanged: (enabled) {
            onSettingsChanged(settings.copyWith(confirmResetEnabled: enabled));
          },
        ),
        const SizedBox(height: 24),
        const _SettingsSectionTitle(
          label: 'FEEDBACK',
          subtitle: 'Tune what you hear and feel when the board responds.',
        ),
        const SizedBox(height: 14),
        _SettingsToggleCard(
          icon: Icons.graphic_eq_rounded,
          title: 'Sound Effects',
          description:
              'Plays the round sequence tones and tap confirmations during the run.',
          value: settings.soundEnabled,
          accent: NeuralTheme.primarySoft,
          onChanged: (enabled) {
            onSettingsChanged(settings.copyWith(soundEnabled: enabled));
          },
        ),
        const SizedBox(height: 14),
        _SettingsSliderCard(
          icon: Icons.volume_up_rounded,
          title: 'Sound Intensity',
          description:
              'Sets the loudness of the game effects without touching your phone volume.',
          value: settings.soundLevel,
          min: 0.20,
          max: 1.00,
          divisions: 8,
          accent: NeuralTheme.tertiary,
          enabled: settings.soundEnabled,
          valueLabel: '${(settings.soundLevel * 100).round()}%',
          onChanged: (value) {
            onSettingsChanged(settings.copyWith(soundLevel: value));
          },
        ),
        const SizedBox(height: 14),
        _SettingsToggleCard(
          icon: Icons.vibration_rounded,
          title: 'Haptic Feedback',
          description:
              'Adds tactile pulses for sequence playback, taps, and mistakes.',
          value: settings.hapticsEnabled,
          accent: NeuralTheme.primarySoft,
          onChanged: (enabled) {
            onSettingsChanged(settings.copyWith(hapticsEnabled: enabled));
          },
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: NeuralTheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: NeuralTheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            'Everything here applies immediately. Theme changes repaint the app, gameplay settings affect new rounds, and feedback changes are ready for your next tap.',
            style: const TextStyle(
              color: NeuralTheme.textMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsHeroCard extends StatelessWidget {
  const _SettingsHeroCard({required this.bestStreak, required this.settings});

  final int bestStreak;
  final NeuralSettings settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NeuralTheme.primary.withValues(alpha: 0.18),
            NeuralTheme.surface,
          ],
        ),
        border: Border.all(color: NeuralTheme.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: NeuralTheme.primaryGlow.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: NeuralTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: NeuralTheme.primary,
                  size: 34,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTROL DECK',
                      style: TextStyle(
                        color: NeuralTheme.primarySoft,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Best streak: $bestStreak. Current theme: ${NeuralTheme.palette.label}. Pace: ${settings.paceLabel}.',
                      style: const TextStyle(
                        color: NeuralTheme.textMuted,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _SettingsStatChip(
                  label: 'BEST CHAIN',
                  value: '$bestStreak',
                  accent: NeuralTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SettingsStatChip(
                  label: 'SFX',
                  value: settings.soundEnabled
                      ? '${(settings.soundLevel * 100).round()}%'
                      : 'OFF',
                  accent: NeuralTheme.secondarySoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SettingsStatChip(
                  label: 'OVERDRIVE',
                  value: settings.overdriveLabel,
                  accent: NeuralTheme.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocalProfileCard extends StatelessWidget {
  const _LocalProfileCard({required this.currentUser, required this.onSignOut});

  final AppUser? currentUser;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: NeuralTheme.secondary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconPlate(
                icon: Icons.person_rounded,
                color: NeuralTheme.secondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCOUNT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: NeuralTheme.textDim.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentUser?.username ?? 'No active account',
                      style: const TextStyle(
                        color: NeuralTheme.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            currentUser == null
                ? 'Sign in to sync runs to your shared account.'
                : 'Best synced score ${_formatNumber(currentUser!.score)}. Sign out here if you want to switch to another player account.',
            style: const TextStyle(
              color: NeuralTheme.textMuted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: currentUser == null ? null : onSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: NeuralTheme.secondarySoft,
                side: BorderSide(
                  color: NeuralTheme.secondary.withValues(alpha: 0.24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'SIGN OUT',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _percent(double value) => '${(value * 100).round()}%';

class _SettingsStatChip extends StatelessWidget {
  const _SettingsStatChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: NeuralTheme.textDim),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeProfileCard extends StatelessWidget {
  const _ThemeProfileCard({
    required this.profile,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppThemeProfile profile;
  final AppThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NeuralTheme.surface.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? palette.primary.withValues(alpha: 0.65)
                    : NeuralTheme.outline.withValues(alpha: 0.24),
                width: selected ? 1.6 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: palette.primaryGlow.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ThemeDot(color: palette.primary),
                    const SizedBox(width: 8),
                    _ThemeDot(color: palette.secondary),
                    const SizedBox(width: 8),
                    _ThemeDot(color: palette.tertiary),
                    const Spacer(),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: palette.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  palette.label,
                  style: TextStyle(
                    color: selected ? palette.primarySoft : NeuralTheme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  switch (profile) {
                    AppThemeProfile.neuralBlue => 'Classic cyber glow',
                    AppThemeProfile.emberGlow => 'Warm neon contrast',
                    AppThemeProfile.mintCircuit => 'Cool arcade pulse',
                  },
                  style: const TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeDot extends StatelessWidget {
  const _ThemeDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({required this.label, required this.subtitle});

  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: NeuralTheme.textDim.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: NeuralTheme.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _SettingsToggleCard extends StatelessWidget {
  const _SettingsToggleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconPlate(icon: icon, color: accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NeuralTheme.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: accent,
            activeTrackColor: accent.withValues(alpha: 0.35),
            inactiveThumbColor: NeuralTheme.textMuted,
            inactiveTrackColor: NeuralTheme.surfaceHighest,
          ),
        ],
      ),
    );
  }
}

class _SettingsSliderCard extends StatelessWidget {
  const _SettingsSliderCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.accent,
    required this.valueLabel,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color accent;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color cardAccent = enabled
        ? accent
        : NeuralTheme.textDim.withValues(alpha: 0.55);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardAccent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconPlate(icon: icon, color: cardAccent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled
                            ? NeuralTheme.text
                            : NeuralTheme.textMuted.withValues(alpha: 0.75),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: enabled
                            ? NeuralTheme.textMuted
                            : NeuralTheme.textDim,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cardAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  valueLabel,
                  style: TextStyle(
                    color: cardAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: cardAccent,
              inactiveTrackColor: NeuralTheme.surfaceHighest,
              thumbColor: cardAccent,
              overlayColor: cardAccent.withValues(alpha: 0.12),
              valueIndicatorColor: cardAccent,
              disabledActiveTrackColor: NeuralTheme.textDim.withValues(
                alpha: 0.22,
              ),
              disabledInactiveTrackColor: NeuralTheme.surfaceHighest,
              disabledThumbColor: NeuralTheme.textDim,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsDashboard extends StatefulWidget {
  const _StatsDashboard({
    required this.currentUser,
    required this.stats,
    required this.sessions,
    required this.leaderboardUsers,
  });

  final AppUser? currentUser;
  final PlayerStats stats;
  final List<GameSession> sessions;
  final List<AppUser> leaderboardUsers;

  @override
  State<_StatsDashboard> createState() => _StatsDashboardState();
}

class _StatsDashboardState extends State<_StatsDashboard> {
  SessionViewFilter _selectedFilter = SessionViewFilter.all;

  @override
  Widget build(BuildContext context) {
    final List<GameSession> recentRuns = widget.sessions.recentRuns(
      mode: _selectedFilter.mode,
      limit: 6,
    );
    final int? currentRank = widget.currentUser == null
        ? null
        : widget.leaderboardUsers.indexWhere(
                (AppUser user) => user.id == widget.currentUser!.id,
              ) +
              1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PERFORMANCE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: NeuralTheme.textDim.withValues(alpha: 0.52),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.currentUser == null
              ? 'Shared training records appear here after the first synced run.'
              : 'Signed in as ${widget.currentUser!.username}. Runs and scores now sync through the shared backend.',
          style: TextStyle(
            color: NeuralTheme.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        if (widget.currentUser != null &&
            currentRank != null &&
            currentRank > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _LeaderboardSummaryCard(
              rank: currentRank,
              playerCount: widget.leaderboardUsers.length,
              score: widget.currentUser!.score,
            ),
          ),
        _BestStreakCard(bestStreak: widget.stats.bestStreak),
        const SizedBox(height: 16),
        if (widget.sessions.isEmpty)
          const _NoStatsStateCard()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = (constraints.maxWidth - 16) / 2;
              final double cardHeight = math.max(cardWidth, 228);

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _MetricCard(
                      label: 'BEST SCORE',
                      value: _formatNumber(widget.stats.bestScore),
                      accent: NeuralTheme.secondary,
                      icon: Icons.emoji_events_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _MetricCard(
                      label: 'TOTAL SESSIONS',
                      value: _formatNumber(widget.stats.totalSessions),
                      accent: NeuralTheme.primary,
                      icon: Icons.layers_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _MetricCard(
                      label: 'SCORE MEAN',
                      value: _formatAverage(widget.stats.averageScore),
                      accent: NeuralTheme.primarySoft,
                      icon: Icons.bar_chart_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _MetricCard(
                      label: 'ROUND MEAN',
                      value: _formatAverage(widget.stats.averageRoundsReached),
                      accent: NeuralTheme.tertiary,
                      icon: Icons.route_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _MetricCard(
                      label: 'FOCUS BEST',
                      value: _formatNumber(
                        widget.stats.bestScoreByMode[GameModeKey.focus] ?? 0,
                      ),
                      accent: NeuralTheme.primary,
                      icon: Icons.auto_awesome_motion_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _MetricCard(
                      label: 'OVERDRIVE BEST',
                      value: _formatNumber(
                        widget.stats.bestScoreByMode[GameModeKey.overdrive] ??
                            0,
                      ),
                      accent: NeuralTheme.secondarySoft,
                      icon: Icons.bolt_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _MetricCard(
                      label: 'LAST PLAYED',
                      value: _formatDate(widget.stats.lastPlayedAt),
                      accent: NeuralTheme.primarySoft,
                      icon: Icons.event_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 28),
        const _StatsSectionHeader(
          label: 'PLAYER LEADERBOARD',
          subtitle:
              'All shared accounts are ranked here by each player\'s best recorded score.',
        ),
        const SizedBox(height: 16),
        _LeaderboardCard(
          currentUserId: widget.currentUser?.id,
          users: widget.leaderboardUsers,
        ),
        const SizedBox(height: 14),
        const _StatsSectionHeader(
          label: 'YOUR RECENT RUNS',
          subtitle:
              'Review your own completed sessions by mode without mixing them into the player-vs-player rankings.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: SessionViewFilter.values.map((SessionViewFilter filter) {
            return _SessionFilterPill(
              label: filter.label,
              selected: _selectedFilter == filter,
              onTap: () {
                if (_selectedFilter == filter) {
                  return;
                }
                setState(() {
                  _selectedFilter = filter;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Column(
            key: ValueKey<SessionViewFilter>(_selectedFilter),
            children: [
              _RecentRunsCard(runs: recentRuns, filter: _selectedFilter),
            ],
          ),
        ),
      ],
    );
  }
}

enum _AppNoticeTone { info, warning }

@immutable
class _AppNotice {
  const _AppNotice({
    required this.title,
    required this.message,
    required this.icon,
    this.tone = _AppNoticeTone.info,
  });

  final String title;
  final String message;
  final IconData icon;
  final _AppNoticeTone tone;
}

class _StatsSectionHeader extends StatelessWidget {
  const _StatsSectionHeader({required this.label, required this.subtitle});

  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: NeuralTheme.textDim.withValues(alpha: 0.52),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: NeuralTheme.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _LeaderboardSummaryCard extends StatelessWidget {
  const _LeaderboardSummaryCard({
    required this.rank,
    required this.playerCount,
    required this.score,
  });

  final int rank;
  final int playerCount;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NeuralTheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LeaderboardSummaryMetric(
              label: 'GLOBAL RANK',
              value: '#$rank of $playerCount',
              accent: NeuralTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LeaderboardSummaryMetric(
              label: 'PROFILE SCORE',
              value: _formatNumber(score),
              accent: NeuralTheme.secondarySoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardSummaryMetric extends StatelessWidget {
  const _LeaderboardSummaryMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeuralTheme.surfaceHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: NeuralTheme.textDim),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionFilterPill extends StatelessWidget {
  const _SessionFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? NeuralTheme.primary.withValues(alpha: 0.12)
                : NeuralTheme.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? NeuralTheme.primary.withValues(alpha: 0.34)
                  : NeuralTheme.outline.withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? NeuralTheme.primarySoft : NeuralTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.users, required this.currentUserId});

  final List<AppUser> users;
  final int? currentUserId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: NeuralTheme.secondary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconPlate(
                icon: Icons.workspace_premium_rounded,
                color: NeuralTheme.secondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registered players',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: NeuralTheme.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'These rows come from shared player accounts and are ranked by each account\'s best score.',
                      style: TextStyle(
                        color: NeuralTheme.textDim,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (users.isEmpty)
            _DataPlaceholder(
              icon: Icons.leaderboard_rounded,
              title: 'No leaderboard entries yet',
              message:
                  'Create an account and finish a synced run to populate the shared player rankings.',
            )
          else
            Column(
              children: List<Widget>.generate(users.length, (int index) {
                final AppUser user = users[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == users.length - 1 ? 0 : 14,
                  ),
                  child: _LeaderboardEntryRow(
                    rank: index + 1,
                    user: user,
                    isCurrentUser: user.id == currentUserId,
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _LeaderboardEntryRow extends StatelessWidget {
  const _LeaderboardEntryRow({
    required this.rank,
    required this.user,
    required this.isCurrentUser,
  });

  final int rank;
  final AppUser user;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final Color accent = isCurrentUser
        ? NeuralTheme.secondarySoft
        : rank == 1
        ? NeuralTheme.secondary
        : NeuralTheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeuralTheme.surfaceHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(color: accent, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        color: NeuralTheme.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _SessionBadge(
                      label: isCurrentUser ? 'Current player' : 'Player',
                      color: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Best saved score ${_formatNumber(user.score)}',
                  style: TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.lastPlayedAt == null
                      ? 'No completed sessions yet'
                      : 'Last played ${_formatDateTime(user.lastPlayedAt!)}',
                  style: TextStyle(color: NeuralTheme.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            _formatNumber(user.score),
            style: TextStyle(
              color: accent,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRunsCard extends StatelessWidget {
  const _RecentRunsCard({required this.runs, required this.filter});

  final List<GameSession> runs;
  final SessionViewFilter filter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NeuralTheme.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconPlate(
                icon: Icons.history_rounded,
                color: NeuralTheme.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent sessions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: NeuralTheme.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The latest completed runs for ${filter.label.toLowerCase()} stay visible here for quick review.',
                      style: TextStyle(
                        color: NeuralTheme.textDim,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (runs.isEmpty)
            _DataPlaceholder(
              icon: Icons.cloud_off_rounded,
              title: 'No session history yet',
              message:
                  'This panel fills in after the first saved run, so there is always a visible no-data state.',
            )
          else
            Column(
              children: List<Widget>.generate(runs.length, (int index) {
                final GameSession session = runs[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == runs.length - 1 ? 0 : 12,
                  ),
                  child: _RecentRunRow(session: session),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _RecentRunRow extends StatelessWidget {
  const _RecentRunRow({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final Color accent = session.mode == GameModeKey.focus
        ? NeuralTheme.primary
        : NeuralTheme.secondarySoft;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeuralTheme.surfaceHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconPlate(
            icon: session.mode == GameModeKey.focus
                ? Icons.auto_awesome_motion_rounded
                : Icons.bolt_rounded,
            color: accent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      _formatModeLabel(session.mode),
                      style: const TextStyle(
                        color: NeuralTheme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _SessionBadge(
                      label: _formatSessionEndReason(session.endReason),
                      color: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Score ${_formatNumber(session.score)}  •  Chain ${session.bestStreak}  •  Round ${session.roundReached}',
                  style: TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatDateTime(session.endedAt),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: NeuralTheme.textDim,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionBadge extends StatelessWidget {
  const _SessionBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DataPlaceholder extends StatelessWidget {
  const _DataPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NeuralTheme.surfaceHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NeuralTheme.outline.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconPlate(icon: icon, color: NeuralTheme.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NeuralTheme.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoStatsStateCard extends StatelessWidget {
  const _NoStatsStateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NeuralTheme.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconPlate(
                icon: Icons.inbox_rounded,
                color: NeuralTheme.primarySoft,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'No sessions have been saved yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: NeuralTheme.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'The stats screen stays readable even with no data. After the first completed run, this panel fills with score, round, and mode-specific summaries automatically.',
            style: TextStyle(
              color: NeuralTheme.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppNoticeBanner extends StatelessWidget {
  const _AppNoticeBanner({
    super.key,
    required this.notice,
    required this.onDismiss,
  });

  final _AppNotice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bool isWarning = notice.tone == _AppNoticeTone.warning;
    final Color accent = isWarning
        ? NeuralTheme.secondarySoft
        : NeuralTheme.primarySoft;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NeuralTheme.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.14),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconPlate(icon: notice.icon, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: const TextStyle(
                      color: NeuralTheme.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notice.message,
                    style: TextStyle(
                      color: NeuralTheme.textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _RoundIconButton(
              icon: Icons.close_rounded,
              color: NeuralTheme.surfaceHighest,
              iconColor: NeuralTheme.textDim,
              onTap: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconPlate(icon: icon, color: accent),
          const SizedBox(height: 16),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: NeuralTheme.textMuted),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeuralHomeShell extends StatefulWidget {
  const _NeuralHomeShell({
    required this.currentUser,
    required this.playerStats,
    required this.sessions,
    required this.leaderboardUsers,
    required this.appNotice,
    required this.settings,
    required this.onSessionCompleted,
    required this.onDismissNotice,
    required this.onSettingsChanged,
    required this.onSignOut,
  });

  final ValueNotifier<AppUser?> currentUser;
  final ValueNotifier<PlayerStats> playerStats;
  final ValueNotifier<List<GameSession>> sessions;
  final ValueNotifier<List<AppUser>> leaderboardUsers;
  final ValueNotifier<_AppNotice?> appNotice;
  final ValueNotifier<NeuralSettings> settings;
  final Future<void> Function(GameSession session) onSessionCompleted;
  final VoidCallback onDismissNotice;
  final ValueChanged<NeuralSettings> onSettingsChanged;
  final Future<void> Function() onSignOut;

  @override
  State<_NeuralHomeShell> createState() => _NeuralHomeShellState();
}

class _NeuralHomeShellState extends State<_NeuralHomeShell> {
  NeuralNavItem _selected = NeuralNavItem.grid;

  void _goToItem(NeuralNavItem item) {
    if (_selected == item) {
      return;
    }

    setState(() {
      _selected = item;
    });
  }

  Duration _tabTransitionDuration(NeuralSettings settings) {
    return settings.tuneDuration(
      const Duration(milliseconds: 220),
      reducedFactor: 0.55,
      minMilliseconds: 110,
    );
  }

  Widget _buildScreen(NeuralNavItem item) {
    switch (item) {
      case NeuralNavItem.grid:
        return MainMenuScreen(
          key: const PageStorageKey<String>('home-main-menu'),
          currentUser: widget.currentUser,
          playerStats: widget.playerStats,
          settings: widget.settings,
          onSessionCompleted: widget.onSessionCompleted,
          onOpenSettings: () => _goToItem(NeuralNavItem.settings),
        );
      case NeuralNavItem.stats:
        return StatsScreen(
          key: const PageStorageKey<String>('home-stats'),
          currentUser: widget.currentUser,
          playerStats: widget.playerStats,
          sessions: widget.sessions,
          leaderboardUsers: widget.leaderboardUsers,
          settings: widget.settings,
        );
      case NeuralNavItem.settings:
        return SettingsScreen(
          key: const PageStorageKey<String>('home-settings'),
          currentUser: widget.currentUser,
          playerStats: widget.playerStats,
          settings: widget.settings,
          onSettingsChanged: widget.onSettingsChanged,
          onSignOut: widget.onSignOut,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final NeuralSettings currentSettings = widget.settings.value;
    final Duration transitionDuration = _tabTransitionDuration(currentSettings);
    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: transitionDuration,
            reverseDuration: transitionDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren,
                  if (currentChild case final Widget currentChild) currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              final Animation<double> curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              final Animation<Offset> slideAnimation = Tween<Offset>(
                begin: const Offset(0.035, 0),
                end: Offset.zero,
              ).animate(curvedAnimation);
              return FadeTransition(
                opacity: curvedAnimation,
                child: SlideTransition(position: slideAnimation, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<NeuralNavItem>(_selected),
              child: RepaintBoundary(child: _buildScreen(_selected)),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 70, 16, 0),
                child: ValueListenableBuilder<_AppNotice?>(
                  valueListenable: widget.appNotice,
                  builder: (context, notice, _) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: notice == null
                          ? const SizedBox.shrink()
                          : _AppNoticeBanner(
                              key: ValueKey<String>(
                                '${notice.title}:${notice.message}',
                              ),
                              notice: notice,
                              onDismiss: widget.onDismissNotice,
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NeuralBottomNav(
        selected: _selected,
        onItemSelected: _goToItem,
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.mode,
    required this.initialBestScore,
    required this.settings,
    required this.onSessionCompleted,
  });

  final GameMode mode;
  final int initialBestScore;
  final NeuralSettings settings;
  final Future<void> Function(GameSession session) onSessionCompleted;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final math.Random _random;
  late final int _tileCount;
  late final NeuralSoundController _soundController;
  final List<int> _sequence = <int>[];
  Timer? _inputTimer;
  int _sessionId = 0;
  int? _highlightedTile;
  int? _pressedTile;
  int? _errorTile;
  int _score = 0;
  int _streak = 0;
  int _bestRun = 0;
  int _round = 0;
  int _inputIndex = 0;
  int _roundAudioStreak = 0;
  int _tapFeedbackVersion = 0;
  double _sequenceProgress = 0;
  double _timerProgress = 1;
  GamePhase _phase = GamePhase.booting;
  bool _isSubmitting = false;
  bool _isResolvingFailureTap = false;
  bool _didRecordCurrentSession = false;
  bool? _lastAppliedFocusMode;
  DateTime? _sessionStartedAt;

  @override
  void initState() {
    super.initState();
    _random = math.Random();
    _tileCount = widget.mode.gridSize * widget.mode.gridSize;
    _soundController = NeuralSoundController();
    unawaited(_soundController.warmUp());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startNewGame());
    });
  }

  int _nextTile(int current) {
    if (_tileCount == 1) {
      return current;
    }
    int next = _random.nextInt(_tileCount);
    while (next == current) {
      next = _random.nextInt(_tileCount);
    }
    return next;
  }

  Future<void> _startNewGame() async {
    final int session = ++_sessionId;
    final DateTime startedAt = DateTime.now();
    _cancelInputTimer();
    if (mounted) {
      setState(() {
        _sequence.clear();
        _highlightedTile = null;
        _pressedTile = null;
        _errorTile = null;
        _score = 0;
        _streak = 0;
        _bestRun = 0;
        _round = 0;
        _inputIndex = 0;
        _roundAudioStreak = 0;
        _sequenceProgress = 0;
        _timerProgress = 1;
        _phase = GamePhase.booting;
      });
    }
    _tapFeedbackVersion += 1;
    _isResolvingFailureTap = false;
    _didRecordCurrentSession = false;
    _sessionStartedAt = startedAt;

    await Future<void>.delayed(
      widget.settings.tuneDuration(
        const Duration(milliseconds: 320),
        reducedFactor: 0.75,
        minMilliseconds: 160,
      ),
    );
    if (!_sessionIsActive(session)) {
      return;
    }
    await _startNextRound(session);
  }

  Future<void> _startNextRound(int session) async {
    if (!_sessionIsActive(session)) {
      return;
    }

    final int nextTile = _sequence.isEmpty
        ? _random.nextInt(_tileCount)
        : _nextTile(_sequence.last);

    setState(() {
      _sequence.add(nextTile);
      _round = _sequence.length;
      _inputIndex = 0;
      _roundAudioStreak = _streak;
      _tapFeedbackVersion += 1;
      _sequenceProgress = 0;
      _timerProgress = 1;
      _highlightedTile = null;
      _pressedTile = null;
      _errorTile = null;
      _phase = GamePhase.showing;
    });

    await Future<void>.delayed(_roundLeadInDuration);
    if (!_sessionIsActive(session)) {
      return;
    }

    await _playSequence(session);
    if (!_sessionIsActive(session)) {
      return;
    }
    _beginInput(session);
  }

  Future<void> _playSequence(int session) async {
    for (int index = 0; index < _sequence.length; index++) {
      if (!_sessionIsActive(session)) {
        return;
      }

      setState(() {
        _highlightedTile = _sequence[index];
        _pressedTile = null;
        _errorTile = null;
        _sequenceProgress = index / _sequence.length;
      });
      _playSequenceHaptic();
      unawaited(
        _soundController.playSequenceStep(
          streak: _roundAudioStreak,
          enabled: widget.settings.soundEnabled,
          masterVolume: widget.settings.effectiveSoundLevel,
        ),
      );

      await Future<void>.delayed(_flashDuration);
      if (!_sessionIsActive(session)) {
        return;
      }

      setState(() {
        _highlightedTile = null;
        _sequenceProgress = (index + 1) / _sequence.length;
      });

      await Future<void>.delayed(_flashGapDuration);
    }
  }

  void _beginInput(int session) {
    if (!_sessionIsActive(session)) {
      return;
    }

    setState(() {
      _phase = GamePhase.input;
      _sequenceProgress = 0;
      _timerProgress = 1;
    });
    _armInputTimer(session);
  }

  Duration? _inputWindowForCurrentTurn() {
    final Duration? baseTapTimeout = widget.mode.baseTapTimeout;
    if (baseTapTimeout == null) {
      return null;
    }
    return widget.settings.tuneOverdriveWindow(baseTapTimeout, round: _round);
  }

  void _armInputTimer(int session) {
    _cancelInputTimer();
    final Duration? inputWindow = _inputWindowForCurrentTurn();
    if (inputWindow == null) {
      return;
    }

    final DateTime deadline = DateTime.now().add(inputWindow);
    _inputTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_sessionIsActive(session) || _phase != GamePhase.input) {
        timer.cancel();
        return;
      }

      final int remainingMs = deadline
          .difference(DateTime.now())
          .inMilliseconds;
      if (remainingMs <= 0) {
        timer.cancel();
        if (!mounted || session != _sessionId) {
          return;
        }

        setState(() {
          _timerProgress = 0;
        });
        unawaited(
          _handleFailure(
            summary: 'Time expired',
            endReason: SessionEndReason.timedOut,
          ),
        );
        return;
      }

      if (mounted && session == _sessionId) {
        setState(() {
          _timerProgress = (remainingMs / inputWindow.inMilliseconds).clamp(
            0.0,
            1.0,
          );
        });
      }
    });
  }

  Future<void> _handleTileTap(int index) async {
    if (_isSubmitting || _isResolvingFailureTap || _phase != GamePhase.input) {
      return;
    }

    final int session = _sessionId;
    final int expectedTile = _sequence[_inputIndex];
    final bool isCorrectTile = index == expectedTile;
    final int nextInputIndex = _inputIndex + 1;
    final bool completesRound =
        isCorrectTile && nextInputIndex >= _sequence.length;
    final int feedbackVersion = _tapFeedbackVersion + 1;
    _cancelInputTimer();

    setState(() {
      _tapFeedbackVersion = feedbackVersion;
      _pressedTile = index;
      _errorTile = null;
      _highlightedTile = null;
      if (isCorrectTile) {
        _inputIndex = nextInputIndex;
        _sequenceProgress = nextInputIndex / _sequence.length;
        _score += widget.mode.pointsPerStep;
        _streak += 1;
        _bestRun = math.max(_bestRun, _streak);
        _timerProgress = 1;
        if (completesRound) {
          _score += widget.mode.roundBonus;
          _phase = GamePhase.roundClear;
        }
      }
    });
    _playTapHaptic();
    unawaited(
      _soundController.playTap(
        streak: _roundAudioStreak,
        completedRound: completesRound,
        enabled: widget.settings.soundEnabled,
        masterVolume: widget.settings.effectiveSoundLevel,
      ),
    );

    if (index != expectedTile) {
      _isResolvingFailureTap = true;
      setState(() {
        _pressedTile = null;
        _errorTile = index;
      });
      _playFailureHaptic();
      await Future<void>.delayed(_errorFlashDuration);
      if (_sessionIsActive(session)) {
        await _handleFailure(
          summary: 'Wrong tile',
          endReason: SessionEndReason.wrongTile,
          errorTile: index,
        );
      }
      return;
    }

    _playSuccessHaptic(completedRound: completesRound);

    if (completesRound) {
      await _clearPressedTileAfterDelay(
        session: session,
        feedbackVersion: feedbackVersion,
        duration: _tapPressDuration,
      );
      if (!_sessionIsActive(session) ||
          feedbackVersion != _tapFeedbackVersion) {
        return;
      }
      await Future<void>.delayed(_roundLeadInDuration);
      if (_sessionIsActive(session) && feedbackVersion == _tapFeedbackVersion) {
        await _startNextRound(session);
      }
      return;
    }

    unawaited(
      _clearPressedTileAfterDelay(
        session: session,
        feedbackVersion: feedbackVersion,
        duration: _tapPressDuration,
      ),
    );
    _armInputTimer(session);
  }

  Future<void> _handleFailure({
    required String summary,
    required SessionEndReason endReason,
    int? errorTile,
  }) async {
    if (_isSubmitting || _didRecordCurrentSession) {
      return;
    }

    _isSubmitting = true;
    _isResolvingFailureTap = false;
    _tapFeedbackVersion += 1;
    _didRecordCurrentSession = true;
    _cancelInputTimer();
    setState(() {
      _phase = GamePhase.failed;
      _highlightedTile = null;
      _pressedTile = null;
      _errorTile = errorTile;
      _sequenceProgress = 1;
      _timerProgress = 0;
    });

    final DateTime endedAt = DateTime.now();
    final GameSession completedSession = GameSession(
      id: '${widget.mode.statsKey.name}-${endedAt.microsecondsSinceEpoch}',
      mode: widget.mode.statsKey,
      startedAt: _sessionStartedAt ?? endedAt,
      endedAt: endedAt,
      score: _score,
      bestStreak: _bestRun,
      roundReached: _round,
      endReason: endReason,
    );

    final bool restart =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => GameOverDialog(
            mode: widget.mode,
            score: _score,
            bestRun: _bestRun,
            roundReached: _round,
            summary: summary,
            newHighScore: _score > widget.initialBestScore,
          ),
        ) ??
        false;

    try {
      await widget.onSessionCompleted(completedSession);
    } finally {
      _isSubmitting = false;
    }

    if (!mounted) {
      return;
    }
    if (restart) {
      unawaited(_startNewGame());
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _clearPressedTileAfterDelay({
    required int session,
    required int feedbackVersion,
    required Duration duration,
  }) async {
    await Future<void>.delayed(duration);
    if (!_sessionIsActive(session) ||
        feedbackVersion != _tapFeedbackVersion ||
        !mounted) {
      return;
    }

    setState(() {
      _pressedTile = null;
    });
  }

  Duration get _tapPressDuration => widget.settings.tuneDuration(
    Duration(milliseconds: widget.mode == GameMode.focus ? 150 : 100),
    reducedFactor: 0.72,
    minMilliseconds: 70,
  );

  Duration get _errorFlashDuration => widget.settings.tuneDuration(
    const Duration(milliseconds: 180),
    reducedFactor: 0.72,
    minMilliseconds: 90,
  );

  Duration get _flashDuration => widget.settings.tuneDuration(
    widget.mode.flashDuration,
    reducedFactor: 0.68,
    minMilliseconds: 110,
  );

  Duration get _flashGapDuration => widget.settings.tuneDuration(
    widget.mode.flashGap,
    reducedFactor: 0.68,
    minMilliseconds: 50,
  );

  Duration get _roundLeadInDuration => widget.settings.tuneDuration(
    widget.mode.roundLeadIn,
    reducedFactor: 0.72,
    minMilliseconds: 140,
  );

  void _playSequenceHaptic() {
    if (!widget.settings.hapticsEnabled) {
      return;
    }
    unawaited(HapticFeedback.selectionClick());
  }

  void _playTapHaptic() {
    if (!widget.settings.hapticsEnabled) {
      return;
    }
    unawaited(HapticFeedback.lightImpact());
  }

  void _playSuccessHaptic({required bool completedRound}) {
    if (!widget.settings.hapticsEnabled) {
      return;
    }
    unawaited(
      completedRound
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.selectionClick(),
    );
  }

  void _playFailureHaptic() {
    if (!widget.settings.hapticsEnabled) {
      return;
    }
    unawaited(HapticFeedback.heavyImpact());
  }

  bool _sessionIsActive(int session) {
    return mounted && session == _sessionId && !_isSubmitting;
  }

  void _cancelInputTimer() {
    _inputTimer?.cancel();
    _inputTimer = null;
  }

  Future<void> _resetGame() async {
    if (widget.settings.confirmResetEnabled) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _ResetConfirmDialog(),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    unawaited(_startNewGame());
  }

  bool get _isGameRunning =>
      !_isSubmitting &&
      (_phase == GamePhase.booting ||
          _phase == GamePhase.showing ||
          _phase == GamePhase.input ||
          _phase == GamePhase.roundClear);

  @override
  void dispose() {
    _sessionId += 1;
    _cancelInputTimer();
    unawaited(_configureEdgeToEdgeUi());
    unawaited(_soundController.dispose());
    super.dispose();
  }

  void _syncSystemUi(bool isGameRunning) {
    if (_lastAppliedFocusMode == isGameRunning) {
      return;
    }
    _lastAppliedFocusMode = isGameRunning;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        isGameRunning ? _configureFullscreenUi() : _configureEdgeToEdgeUi(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isFocus = widget.mode == GameMode.focus;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double bottomNavHeight = _navBarBaseHeight + bottomInset;
    final bool isGameRunning = _isGameRunning;
    _syncSystemUi(isGameRunning);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(color: NeuralTheme.background),
        child: Stack(
          children: [
            _BackgroundEffects(),
            SafeArea(
              bottom: !isGameRunning,
              child: Column(
                children: [
                  if (!isGameRunning)
                    NeuralTopBar(
                      onAction: () => Navigator.of(context).pop(),
                      actionIcon: Icons.home_rounded,
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        isGameRunning ? 24 : 8,
                        24,
                        isGameRunning ? 24 : bottomNavHeight,
                      ),
                      child: _ScaleToFit(
                        designWidth: _gameScreenDesignWidth,
                        designHeight: _gameScreenDesignHeight,
                        child: Column(
                          children: [
                            if (isFocus)
                              _FocusDashboard(
                                score: _score,
                                streak: _streak,
                                round: _round,
                                progress: _sequenceProgress,
                                onReset: () => unawaited(_resetGame()),
                              )
                            else
                              _OverdriveDashboard(
                                score: _score,
                                streak: _streak,
                                round: _round,
                                progress: _sequenceProgress,
                                timerProgress: _timerProgress,
                                onReset: () => unawaited(_resetGame()),
                              ),
                            const SizedBox(height: 20),
                            _ModeProgress(
                              mode: widget.mode,
                              round: _round,
                              progress: _sequenceProgress,
                              timerProgress:
                                  _inputWindowForCurrentTurn() == null
                                  ? null
                                  : _timerProgress,
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: _GameBoard(
                                  gridSize: widget.mode.gridSize,
                                  highlightedTile: _highlightedTile,
                                  pressedTile: _pressedTile,
                                  errorTile: _errorTile,
                                  accent: widget.mode.accent,
                                  icon: widget.mode.icon,
                                  enabled: _phase == GamePhase.input,
                                  onTap: _handleTileTap,
                                ),
                              ),
                            ),
                            if (widget.settings.trainingHintsEnabled)
                              const SizedBox(height: 20),
                            if (widget.settings.trainingHintsEnabled)
                              _ModeHintCard(
                                mode: widget.mode,
                                phase: _phase,
                                round: _round,
                                tapWindow: _inputWindowForCurrentTurn(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isGameRunning)
              const Align(
                alignment: Alignment.bottomCenter,
                child: NeuralBottomNav(selected: NeuralNavItem.grid),
              ),
          ],
        ),
      ),
    );
  }
}

class NeuralTopBar extends StatelessWidget {
  const NeuralTopBar({
    super.key,
    this.onAction,
    this.actionIcon = Icons.settings_rounded,
  });

  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const SizedBox(width: 48),
          const SizedBox(width: 12),
          Icon(Icons.memory_rounded, color: NeuralTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'NEURAL RECALL',
              style: TextStyle(
                color: NeuralTheme.primary,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.6,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: onAction == null
                ? null
                : _RoundIconButton(
                    icon: actionIcon,
                    color: NeuralTheme.surfaceHighest,
                    iconColor: NeuralTheme.textDim,
                    onTap: onAction,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScaleToFit extends StatelessWidget {
  const _ScaleToFit({
    required this.designWidth,
    required this.designHeight,
    required this.child,
  });

  final double designWidth;
  final double designHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(width: designWidth, height: designHeight, child: child),
      ),
    );
  }
}

class _BestStreakCard extends StatelessWidget {
  const _BestStreakCard({required this.bestStreak});

  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NeuralTheme.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: NeuralTheme.primaryGlow.withValues(alpha: 0.28),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'BEST STREAK',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: NeuralTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$bestStreak',
                style: TextStyle(
                  color: NeuralTheme.primarySoft,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: NeuralTheme.primaryGlow.withValues(alpha: 0.55),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'NODES',
                  style: TextStyle(
                    color: NeuralTheme.primarySoft.withValues(alpha: 0.7),
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.mode, required this.onTap});

  final GameMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isOverdrive = mode == GameMode.overdrive;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          height: 142,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isOverdrive
                ? NeuralTheme.secondary.withValues(alpha: 0.12)
                : NeuralTheme.surfaceHigh,
            border: Border.all(
              color: isOverdrive
                  ? NeuralTheme.secondary.withValues(alpha: 0.20)
                  : NeuralTheme.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.menuTitle,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isOverdrive
                            ? NeuralTheme.secondarySoft
                            : NeuralTheme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mode.subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: isOverdrive
                            ? NeuralTheme.secondarySoft.withValues(alpha: 0.56)
                            : NeuralTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Icon(
                mode.icon,
                size: 38,
                color: isOverdrive
                    ? NeuralTheme.secondarySoft.withValues(alpha: 0.85)
                    : NeuralTheme.primary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusDashboard extends StatelessWidget {
  const _FocusDashboard({
    required this.score,
    required this.streak,
    required this.round,
    required this.progress,
    required this.onReset,
  });

  final int score;
  final int streak;
  final int round;
  final double progress;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _MetricBlock(
                label: 'CURRENT SCORE',
                value: _formatNumber(score),
                valueColor: NeuralTheme.primary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: NeuralTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: NeuralTheme.outline.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: NeuralTheme.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'R$round  |  $streak CHAIN',
                    style: TextStyle(
                      color: NeuralTheme.tertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _RoundIconButton(
              icon: Icons.restart_alt_rounded,
              color: NeuralTheme.surface,
              iconColor: NeuralTheme.textMuted,
              onTap: onReset,
            ),
          ],
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: NeuralTheme.surfaceHighest,
            valueColor: AlwaysStoppedAnimation<Color>(NeuralTheme.primary),
          ),
        ),
      ],
    );
  }
}

class _OverdriveDashboard extends StatelessWidget {
  const _OverdriveDashboard({
    required this.score,
    required this.streak,
    required this.round,
    required this.progress,
    required this.timerProgress,
    required this.onReset,
  });

  final int score;
  final int streak;
  final int round;
  final double progress;
  final double timerProgress;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _MetricBlock(
                label: 'CURRENT SCORE',
                value: _formatNumber(score),
                valueColor: NeuralTheme.primarySoft,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: NeuralTheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: NeuralTheme.secondarySoft.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: NeuralTheme.secondarySoft,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'R$round  |  X$streak',
                        style: TextStyle(
                          color: NeuralTheme.secondarySoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('RESET SEQUENCE'),
                  style: TextButton.styleFrom(
                    foregroundColor: NeuralTheme.textMuted,
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: NeuralTheme.surfaceHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              NeuralTheme.secondarySoft,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 92,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: timerProgress,
                minHeight: 6,
                backgroundColor: NeuralTheme.surfaceHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  NeuralTheme.tertiary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: NeuralTheme.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            height: 0.95,
            shadows: [
              Shadow(color: valueColor.withValues(alpha: 0.30), blurRadius: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeProgress extends StatelessWidget {
  const _ModeProgress({
    required this.mode,
    required this.round,
    required this.progress,
    this.timerProgress,
  });

  final GameMode mode;
  final int round;
  final double progress;
  final double? timerProgress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 4,
                  color: NeuralTheme.surfaceHighest,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: mode == GameMode.focus
                              ? [NeuralTheme.primary, NeuralTheme.primarySoft]
                              : [NeuralTheme.primary, NeuralTheme.secondary],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              mode.scoreLabel,
              style: TextStyle(
                color: mode == GameMode.focus
                    ? NeuralTheme.primary
                    : NeuralTheme.primarySoft,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              round == 0 ? 'ROUND 0' : 'ROUND $round',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: NeuralTheme.textMuted),
            ),
            if (timerProgress != null)
              SizedBox(
                width: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: timerProgress,
                    minHeight: 4,
                    backgroundColor: NeuralTheme.surfaceHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      NeuralTheme.tertiary,
                    ),
                  ),
                ),
              )
            else
              Text(
                'UNTIMED',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: NeuralTheme.primarySoft.withValues(alpha: 0.65),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GameBoard extends StatelessWidget {
  const _GameBoard({
    required this.gridSize,
    required this.highlightedTile,
    required this.pressedTile,
    required this.errorTile,
    required this.accent,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final int gridSize;
  final int? highlightedTile;
  final int? pressedTile;
  final int? errorTile;
  final Color accent;
  final IconData icon;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: NeuralTheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gridSize * gridSize,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final bool active =
                index == highlightedTile || index == pressedTile;
            return _BoardTile(
              active: active,
              error: index == errorTile,
              accent: accent,
              icon: icon,
              enabled: enabled,
              onTap: enabled ? () => onTap(index) : null,
            );
          },
        ),
      ),
    );
  }
}

class _BoardTile extends StatelessWidget {
  const _BoardTile({
    required this.active,
    required this.error,
    required this.accent,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final bool active;
  final bool error;
  final Color accent;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: error
              ? NeuralTheme.errorContainer.withValues(alpha: 0.90)
              : active
              ? accent
              : NeuralTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: error
                ? NeuralTheme.error.withValues(alpha: 0.40)
                : active
                ? NeuralTheme.primarySoft.withValues(alpha: 0.30)
                : NeuralTheme.outline.withValues(alpha: 0.12),
            width: active || error ? 2 : 1,
          ),
          boxShadow: active || error
              ? [
                  BoxShadow(
                    color: (error ? NeuralTheme.error : accent).withValues(
                      alpha: 0.45,
                    ),
                    blurRadius: 26,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: active || error
                ? 1
                : enabled
                ? 0.24
                : 0.12,
            child: Icon(
              error
                  ? Icons.close_rounded
                  : active
                  ? icon
                  : Icons.grid_4x4_rounded,
              size: active || error ? 38 : 24,
              color: active || error ? Colors.white : NeuralTheme.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeHintCard extends StatelessWidget {
  const _ModeHintCard({
    required this.mode,
    required this.phase,
    required this.round,
    required this.tapWindow,
  });

  final GameMode mode;
  final GamePhase phase;
  final int round;
  final Duration? tapWindow;

  String get _title {
    if (mode == GameMode.focus) {
      return phase == GamePhase.input ? 'FOCUS LOOP' : 'PATTERN BRIEF';
    }
    return phase == GamePhase.input ? 'OVERDRIVE LIVE' : 'RAPID SYNC';
  }

  String get _message {
    switch (phase) {
      case GamePhase.booting:
        return 'Calibrating the board. The first pattern is loading now.';
      case GamePhase.showing:
        return mode == GameMode.focus
            ? 'Watch the sequence carefully. One new tile is appended every round.'
            : 'The sequence plays at high speed. Track the pattern before the board unlocks.';
      case GamePhase.input:
        if (mode == GameMode.focus) {
          return 'Repeat the full pattern in order. Focus mode has no timer, so precision matters more than speed.';
        }
        final int tapWindowMs = tapWindow?.inMilliseconds ?? 0;
        return 'Repeat the pattern before the timer burns down. Current tap window: ${tapWindowMs}ms.';
      case GamePhase.roundClear:
        return 'Round $round completed. Prepare for one more step in the chain.';
      case GamePhase.failed:
        return 'Sequence lost. Reset the loop and rebuild the chain from round one.';
    }
  }

  IconData get _icon {
    if (mode == GameMode.focus) {
      return Icons.psychology_rounded;
    }
    return phase == GamePhase.input
        ? Icons.flash_on_rounded
        : Icons.rocket_launch_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NeuralTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NeuralTheme.outline.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconPlate(
            icon: _icon,
            color: mode == GameMode.focus
                ? NeuralTheme.secondary
                : NeuralTheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: NeuralTheme.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _message,
                  style: const TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetConfirmDialog extends StatelessWidget {
  const _ResetConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: NeuralTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: NeuralTheme.outline.withValues(alpha: 0.24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RESET CURRENT RUN?',
              style: TextStyle(
                color: NeuralTheme.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your active score, round, and chain will be cleared immediately.',
              style: TextStyle(
                color: NeuralTheme.textMuted,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NeuralTheme.textMuted,
                      side: BorderSide(
                        color: NeuralTheme.outline.withValues(alpha: 0.28),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('KEEP RUNNING'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: NeuralTheme.primary,
                      foregroundColor: NeuralTheme.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'RESET',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GameOverDialog extends StatelessWidget {
  const GameOverDialog({
    super.key,
    required this.mode,
    required this.score,
    required this.bestRun,
    required this.roundReached,
    required this.summary,
    required this.newHighScore,
  });

  final GameMode mode;
  final int score;
  final int bestRun;
  final int roundReached;
  final String summary;
  final bool newHighScore;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: NeuralTheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: NeuralTheme.outline.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: NeuralTheme.primaryGlow.withValues(alpha: 0.25),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -90,
              child: _GlowOrb(
                size: 180,
                color: NeuralTheme.secondary.withValues(alpha: 0.13),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -90,
              child: _GlowOrb(
                size: 180,
                color: NeuralTheme.primary.withValues(alpha: 0.08),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: NeuralTheme.errorContainer.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NeuralTheme.error.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.heart_broken_rounded,
                    color: NeuralTheme.error,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'NEURAL LINK SEVERED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: NeuralTheme.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: 48,
                  height: 3,
                  decoration: BoxDecoration(
                    color: NeuralTheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: mode.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: mode.accent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    mode.label.toUpperCase(),
                    style: TextStyle(
                      color: mode == GameMode.focus
                          ? NeuralTheme.primarySoft
                          : NeuralTheme.secondarySoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'FINAL SCORE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: NeuralTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNumber(score),
                  style: const TextStyle(
                    color: NeuralTheme.text,
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.8,
                  ),
                ),
                const SizedBox(height: 12),
                if (newHighScore)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: NeuralTheme.secondary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: NeuralTheme.secondarySoft.withValues(
                          alpha: 0.20,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          color: NeuralTheme.secondarySoft,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'NEW HIGH SCORE',
                          style: TextStyle(
                            color: NeuralTheme.secondarySoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  summary,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Best chain: $bestRun inputs  |  Round reached: $roundReached',
                  style: const TextStyle(
                    color: NeuralTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: NeuralTheme.primary,
                      foregroundColor: NeuralTheme.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'PLAY AGAIN',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NeuralTheme.textMuted,
                      side: BorderSide(
                        color: NeuralTheme.outline.withValues(alpha: 0.30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'MAIN MENU',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum NeuralNavItem { grid, stats, settings }

class NeuralBottomNav extends StatelessWidget {
  const NeuralBottomNav({
    super.key,
    required this.selected,
    this.onItemSelected,
  });

  final NeuralNavItem selected;
  final ValueChanged<NeuralNavItem>? onItemSelected;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 10, 24, math.max(12, bottomInset)),
      decoration: BoxDecoration(
        color: NeuralTheme.background.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: NeuralTheme.primary.withValues(alpha: 0.14)),
      ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavIcon(
              icon: Icons.grid_view_rounded,
              selected: selected == NeuralNavItem.grid,
              onTap: () => onItemSelected?.call(NeuralNavItem.grid),
            ),
            _NavIcon(
              icon: Icons.stacked_bar_chart_rounded,
              selected: selected == NeuralNavItem.stats,
              onTap: () => onItemSelected?.call(NeuralNavItem.stats),
            ),
            _NavIcon(
              icon: Icons.settings_rounded,
              selected: selected == NeuralNavItem.settings,
              onTap: () => onItemSelected?.call(NeuralNavItem.settings),
            ),
          ],
        ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.selected, this.onTap});

  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: selected
                ? NeuralTheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: NeuralTheme.primaryGlow.withValues(alpha: 0.45),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: selected ? NeuralTheme.primary : const Color(0xFF5D5D5D),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, color: iconColor),
      ),
    );
  }
}

class _IconPlate extends StatelessWidget {
  const _IconPlate({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _BackgroundEffects extends StatelessWidget {
  const _BackgroundEffects();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _GlowOrb(
              size: 280,
              color: NeuralTheme.primaryGlow.withValues(alpha: 0.35),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -100,
            child: _GlowOrb(
              size: 240,
              color: NeuralTheme.secondaryGlow.withValues(alpha: 0.42),
            ),
          ),
          Positioned.fill(child: _GridOverlay()),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 24)],
      ),
    );
  }
}

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.035,
      child: CustomPaint(
        painter: _DotGridPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 40;
    final Paint paint = Paint()..color = Colors.white;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatNumber(int value) {
  final String digits = value.toString();
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final int position = digits.length - i;
    buffer.write(digits[i]);
    if (position > 1 && position % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _formatAverage(double value) {
  if (value == value.roundToDouble()) {
    return _formatNumber(value.round());
  }

  return value.toStringAsFixed(1);
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return 'Never';
  }

  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final DateTime localValue = value.toLocal();
  return '${months[localValue.month - 1]} ${localValue.day}, ${localValue.year}';
}

String _formatDateTime(DateTime value) {
  final DateTime localValue = value.toLocal();
  final String minute = localValue.minute.toString().padLeft(2, '0');
  final String meridiem = localValue.hour >= 12 ? 'PM' : 'AM';
  final int hour = localValue.hour % 12 == 0 ? 12 : localValue.hour % 12;
  return '${_formatDate(localValue)}  •  $hour:$minute $meridiem';
}

String _formatModeLabel(GameModeKey mode) {
  switch (mode) {
    case GameModeKey.focus:
      return 'Easy mode';
    case GameModeKey.overdrive:
      return 'Hard mode';
  }
}

String _formatSessionEndReason(SessionEndReason reason) {
  switch (reason) {
    case SessionEndReason.wrongTile:
      return 'Wrong tile';
    case SessionEndReason.timedOut:
      return 'Timer expired';
  }
}
