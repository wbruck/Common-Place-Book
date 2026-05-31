// Hermetic unit tests for US-004: AuthService.
//
// These tests are fully offline: they inject a fake [AuthClient] into
// [AuthService] so no real network call and no `Supabase.initialize` ever
// runs. The fake lets each test drive the auth-state stream and decide whether
// an operation succeeds or throws a backend [AuthException].

import 'dart:async';

import 'package:common_place_book/core/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds a minimal [User] sufficient for these tests.
User _fakeUser(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.utc(2026, 5, 31).toIso8601String(),
      email: 'user@example.com',
    );

/// Builds a minimal [Session] wrapping [user].
Session _fakeSession(User user) => Session(
      accessToken: 'access-token',
      tokenType: 'bearer',
      user: user,
    );

/// In-memory [AuthClient] fake. No network, no Supabase.
class _FakeAuthClient implements AuthClient {
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  User? _currentUser;

  /// When set, the next operation throws this instead of succeeding.
  AuthException? errorToThrow;

  /// When set, the next operation returns this response.
  AuthResponse? responseToReturn;

  /// Pushes a backend auth state onto the stream.
  void emit(AuthChangeEvent event, {Session? session}) {
    _currentUser = session?.user;
    _controller.add(AuthState(event, session));
  }

  Future<void> dispose() => _controller.close();

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  @override
  User? get currentUser => _currentUser;

  Future<AuthResponse> _runOrThrow() async {
    final error = errorToThrow;
    if (error != null) {
      throw error;
    }
    return responseToReturn ?? AuthResponse();
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      _runOrThrow();

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) =>
      _runOrThrow();

  @override
  Future<void> signOut() async {
    final error = errorToThrow;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    final error = errorToThrow;
    if (error != null) {
      throw error;
    }
  }
}

void main() {
  late _FakeAuthClient client;
  late AuthService service;

  setUp(() {
    client = _FakeAuthClient();
    service = AuthService(client);
  });

  tearDown(() async {
    await client.dispose();
  });

  group('authStateChanges', () {
    test('emits signedIn then signedOut as the backend state changes',
        () async {
      final emitted = <AuthSessionState>[];
      final sub = service.authStateChanges.listen(emitted.add);

      final user = _fakeUser('user-1');
      client
        ..emit(AuthChangeEvent.signedIn, session: _fakeSession(user))
        ..emit(AuthChangeEvent.signedOut);

      // Let the async stream events flush.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(
        emitted,
        [AuthSessionState.signedIn, AuthSessionState.signedOut],
      );
    });

    test('currentUser and isSignedIn track the backend session', () async {
      expect(service.currentUser, isNull);
      expect(service.isSignedIn, isFalse);

      final user = _fakeUser('user-2');
      client.emit(AuthChangeEvent.signedIn, session: _fakeSession(user));

      expect(service.currentUser?.id, 'user-2');
      expect(service.isSignedIn, isTrue);

      client.emit(AuthChangeEvent.signedOut);

      expect(service.currentUser, isNull);
      expect(service.isSignedIn, isFalse);
    });
  });

  group('signUpWithEmail', () {
    test('returns a signed-in outcome when a session is issued', () async {
      final user = _fakeUser('new-user');
      client.responseToReturn = AuthResponse(session: _fakeSession(user));

      final result = await service.signUpWithEmail(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(result.isSuccess, isTrue);
      final value = result.valueOrNull;
      expect(value?.user.id, 'new-user');
      expect(value?.outcome, SignUpOutcome.signedIn);
      expect(value?.isSignedIn, isTrue);
      expect(value?.isConfirmationPending, isFalse);
    });

    test('returns confirmation-pending when a user but no session is returned',
        () async {
      // Supabase default: email confirmation on -> user present, session null.
      client.responseToReturn = AuthResponse(user: _fakeUser('pending-user'));

      final result = await service.signUpWithEmail(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(result.isSuccess, isTrue);
      final value = result.valueOrNull;
      expect(value?.user.id, 'pending-user');
      expect(value?.outcome, SignUpOutcome.confirmationPending);
      expect(value?.isConfirmationPending, isTrue);
      expect(value?.isSignedIn, isFalse);
    });

    test('resolves the user from the session when top-level user is null',
        () async {
      final user = _fakeUser('session-only');
      client.responseToReturn = AuthResponse(session: _fakeSession(user));

      final result = await service.signUpWithEmail(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(result.valueOrNull?.user.id, 'session-only');
      expect(result.valueOrNull?.outcome, SignUpOutcome.signedIn);
    });

    test('fails when neither user nor session is returned', () async {
      client.responseToReturn = AuthResponse();

      final result = await service.signUpWithEmail(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<AuthFailure>());
    });

    test('maps an AuthException to Result.failure with a readable message',
        () async {
      client.errorToThrow = const AuthException(
        'User already registered',
        code: 'user_already_exists',
      );

      final result = await service.signUpWithEmail(
        email: 'taken@example.com',
        password: 'password123',
      );

      expect(result.isFailure, isTrue);
      final failure = result.errorOrNull;
      expect(failure, isA<AuthFailure>());
      expect(failure?.message, 'User already registered');
      expect(failure?.code, 'user_already_exists');
    });
  });

  group('signInWithEmail', () {
    test('returns the user on success', () async {
      final user = _fakeUser('signed-in');
      client.responseToReturn = AuthResponse(session: _fakeSession(user));

      final result = await service.signInWithEmail(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.id, 'signed-in');
    });

    test('maps a wrong-password AuthException to Result.failure', () async {
      client.errorToThrow = const AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      );

      final result = await service.signInWithEmail(
        email: 'user@example.com',
        password: 'wrong',
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.message, 'Invalid login credentials');
    });

    test('maps a missing user (no exception) to Result.failure', () async {
      // Backend returned a response with no user/session.
      client.responseToReturn = AuthResponse();

      final result = await service.signInWithEmail(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<AuthFailure>());
    });
  });

  group('signOut', () {
    test('succeeds when the backend signs out cleanly', () async {
      final result = await service.signOut();
      expect(result.isSuccess, isTrue);
    });

    test('maps an AuthException to Result.failure', () async {
      client.errorToThrow = const AuthException('Sign out failed');

      final result = await service.signOut();

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.message, 'Sign out failed');
    });
  });

  group('sendPasswordResetEmail', () {
    test('succeeds when the reset email is requested', () async {
      final result = await service.sendPasswordResetEmail('user@example.com');
      expect(result.isSuccess, isTrue);
    });

    test('maps an AuthException to Result.failure', () async {
      client.errorToThrow = const AuthException('Unable to send reset email');

      final result = await service.sendPasswordResetEmail('user@example.com');

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.message, 'Unable to send reset email');
    });
  });

  group('LocalOnlyAuthClient via AuthService', () {
    // No backend configured: every auth attempt should fail with the friendly
    // "unavailable in this build" message rather than throwing.
    late AuthService localOnly;

    setUp(() {
      localOnly = AuthService(const LocalOnlyAuthClient());
    });

    test('reports signed out', () {
      expect(localOnly.isSignedIn, isFalse);
      expect(localOnly.currentUser, isNull);
    });

    test('authStateChanges emits an initial signed-out state', () async {
      final first = await localOnly.authStateChanges.first;
      expect(first, AuthSessionState.signedOut);
    });

    test('signInWithEmail fails with the unavailable message', () async {
      final result = await localOnly.signInWithEmail(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(result.isFailure, isTrue);
      expect(
        result.errorOrNull?.message,
        contains('unavailable in this build'),
      );
    });

    test('signUpWithEmail fails with the unavailable message', () async {
      final result = await localOnly.signUpWithEmail(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(result.isFailure, isTrue);
      expect(
        result.errorOrNull?.message,
        contains('unavailable in this build'),
      );
    });

    test('sendPasswordResetEmail fails with the unavailable message', () async {
      final result = await localOnly.sendPasswordResetEmail('user@example.com');

      expect(result.isFailure, isTrue);
      expect(
        result.errorOrNull?.message,
        contains('unavailable in this build'),
      );
    });
  });
}
