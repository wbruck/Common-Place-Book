import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import '../utils/result.dart';

/// App-facing authentication state.
///
/// Intentionally coarse: the rest of the app only needs to know whether a user
/// is signed in, not the full set of gotrue [AuthChangeEvent]s. Keeping this
/// minimal avoids leaking the backend's event model across the codebase.
enum AuthSessionState {
  /// A user is currently authenticated.
  signedIn,

  /// No user is authenticated (the local-first default).
  signedOut,
}

/// A readable authentication failure surfaced through [Result].
///
/// Wraps backend errors so callers (and the UI) get a friendly [message]
/// instead of a raw exception or stack trace. [code] carries the backend error
/// code when present, for callers that want to branch on a specific failure.
class AuthFailure {
  const AuthFailure(this.message, {this.code});

  /// Human-readable, user-safe description of what went wrong.
  final String message;

  /// Backend error code when available (e.g. from [AuthException.code]).
  final String? code;

  @override
  String toString() =>
      code == null ? 'AuthFailure($message)' : 'AuthFailure($message, $code)';
}

/// Minimal authentication client contract that [AuthService] depends on.
///
/// This is the injectable seam: production wraps Supabase's [GoTrueClient] via
/// [SupabaseAuthClient], while tests provide a fake so no network call or
/// `Supabase.initialize` is required.
abstract class AuthClient {
  /// Stream of raw backend auth state changes.
  Stream<AuthState> get onAuthStateChange;

  /// The currently authenticated user, or null when signed out.
  User? get currentUser;

  /// Creates a new account with an email and password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  });

  /// Signs an existing user in with an email and password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });

  /// Signs the current user out.
  Future<void> signOut();

  /// Triggers an email-link password reset for [email].
  Future<void> resetPasswordForEmail(String email);
}

/// [AuthClient] used when no auth backend is available.
///
/// Supabase initialization is skipped when its client config (`SUPABASE_URL`
/// / `SUPABASE_ANON_KEY`) is missing — e.g. a local-only dev build. In that
/// case the app must still boot and stay fully usable logged out, so this
/// client reports a permanently signed-out state and fails any auth attempt
/// with a readable message instead of throwing on a missing `Supabase.instance`.
class LocalOnlyAuthClient implements AuthClient {
  const LocalOnlyAuthClient();

  static const String _unavailable =
      'Sign-in is unavailable in this build. The app works fully offline.';

  @override
  Stream<AuthState> get onAuthStateChange => const Stream<AuthState>.empty();

  @override
  User? get currentUser => null;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      throw const AuthException(_unavailable);

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) =>
      throw const AuthException(_unavailable);

  @override
  Future<void> signOut() async {
    // No session to clear; signing out of a local-only build is a no-op.
  }

  @override
  Future<void> resetPasswordForEmail(String email) =>
      throw const AuthException(_unavailable);
}

/// [AuthClient] implementation backed by Supabase's [GoTrueClient].
class SupabaseAuthClient implements AuthClient {
  const SupabaseAuthClient(this._auth);

  final GoTrueClient _auth;

  @override
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      _auth.signUp(email: email, password: password);

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) =>
      _auth.signInWithPassword(email: email, password: password);

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> resetPasswordForEmail(String email) =>
      _auth.resetPasswordForEmail(email);
}

/// Application authentication service.
///
/// Wraps an [AuthClient] and exposes a small, app-friendly surface:
/// a coarse [authStateChanges] stream, the [currentUser], and operation
/// methods that return [Result] instead of throwing. All diagnostics go
/// through [AppLogger].
///
/// The underlying client is injected so unit tests can supply a fake without
/// touching the network or calling `Supabase.initialize`.
class AuthService {
  AuthService(this._client);

  /// Builds an [AuthService] bound to the live Supabase client.
  ///
  /// Falls back to a [LocalOnlyAuthClient] when Supabase was not initialized
  /// (missing client config), so callers can construct an [AuthService]
  /// unconditionally and the app stays usable logged out. Never throws.
  factory AuthService.fromSupabase() {
    try {
      return AuthService(
        SupabaseAuthClient(Supabase.instance.client.auth),
      );
    } on Object catch (error) {
      AppLogger.warning(
        'Supabase not initialized; using local-only auth. ($error)',
        tag: _logTag,
      );
      return AuthService(const LocalOnlyAuthClient());
    }
  }

  static const String _logTag = 'AuthService';

  final AuthClient _client;

  /// Emits whenever the user signs in or out.
  ///
  /// Maps the backend's fine-grained [AuthChangeEvent]s down to
  /// [AuthSessionState]: any state carrying a session is [signedIn],
  /// otherwise [signedOut].
  Stream<AuthSessionState> get authStateChanges =>
      _client.onAuthStateChange.map(
        (state) => state.session != null
            ? AuthSessionState.signedIn
            : AuthSessionState.signedOut,
      );

  /// The currently authenticated user, or null when signed out.
  User? get currentUser => _client.currentUser;

  /// Whether a user is currently signed in.
  bool get isSignedIn => _client.currentUser != null;

  /// Creates an account with [email] and [password].
  ///
  /// On success the returned [User] is the newly created account (note that
  /// with email confirmation enabled the user may not yet have an active
  /// session until they confirm).
  Future<Result<User, AuthFailure>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.signUp(email: email, password: password);
      final user = response.user;
      if (user == null) {
        AppLogger.warning(
          'Sign-up returned no user',
          tag: _logTag,
        );
        return const Failure(
          AuthFailure('Sign-up did not return a user. Please try again.'),
        );
      }
      AppLogger.info('Sign-up succeeded', tag: _logTag);
      return Success(user);
    } on AuthException catch (error, stackTrace) {
      return _mapAuthException('Sign-up', error, stackTrace);
    } on Object catch (error, stackTrace) {
      return _mapUnexpected('Sign-up', error, stackTrace);
    }
  }

  /// Signs an existing user in with [email] and [password].
  Future<Result<User, AuthFailure>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        AppLogger.warning(
          'Sign-in returned no user',
          tag: _logTag,
        );
        return const Failure(
          AuthFailure('Sign-in failed. Please check your credentials.'),
        );
      }
      AppLogger.info('Sign-in succeeded', tag: _logTag);
      return Success(user);
    } on AuthException catch (error, stackTrace) {
      return _mapAuthException('Sign-in', error, stackTrace);
    } on Object catch (error, stackTrace) {
      return _mapUnexpected('Sign-in', error, stackTrace);
    }
  }

  /// Signs the current user out.
  Future<Result<void, AuthFailure>> signOut() async {
    try {
      await _client.signOut();
      AppLogger.info('Sign-out succeeded', tag: _logTag);
      return const Success(null);
    } on AuthException catch (error, stackTrace) {
      return _mapAuthException('Sign-out', error, stackTrace);
    } on Object catch (error, stackTrace) {
      return _mapUnexpected('Sign-out', error, stackTrace);
    }
  }

  /// Triggers an email-link password reset for [email].
  Future<Result<void, AuthFailure>> sendPasswordResetEmail(
    String email,
  ) async {
    try {
      await _client.resetPasswordForEmail(email);
      AppLogger.info('Password reset email requested', tag: _logTag);
      return const Success(null);
    } on AuthException catch (error, stackTrace) {
      return _mapAuthException('Password reset', error, stackTrace);
    } on Object catch (error, stackTrace) {
      return _mapUnexpected('Password reset', error, stackTrace);
    }
  }

  Result<T, AuthFailure> _mapAuthException<T>(
    String operation,
    AuthException error,
    StackTrace stackTrace,
  ) {
    AppLogger.error(
      '$operation failed',
      tag: _logTag,
      error: error,
      stackTrace: stackTrace,
    );
    return Failure(AuthFailure(error.message, code: error.code));
  }

  Result<T, AuthFailure> _mapUnexpected<T>(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLogger.error(
      '$operation failed unexpectedly',
      tag: _logTag,
      error: error,
      stackTrace: stackTrace,
    );
    return const Failure(
      AuthFailure('Something went wrong. Please try again.'),
    );
  }
}
