// Widget tests for US-007: optional-login UX in Settings.
//
// Fully hermetic: a fake [AuthClient] is injected into a real [AuthService],
// which is provided to [SettingsScreen] via RepositoryProvider. No real
// network call and no `Supabase.initialize` ever run.
//
// Covers the two states the acceptance criteria call out:
//   - signed out  -> "Sign in to sync across devices" (routes to /login)
//   - signed in   -> account email + a "Sign out" action

import 'dart:async';

import 'package:common_place_book/core/auth/auth_service.dart';
import 'package:common_place_book/features/auth/presentation/screens/login_screen.dart';
import 'package:common_place_book/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds a minimal [User] sufficient for these tests.
User _fakeUser(String id, {String email = 'reader@example.com'}) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.utc(2026, 5, 31).toIso8601String(),
      email: email,
    );

/// Builds a minimal [Session] wrapping [user].
Session _fakeSession(User user) => Session(
      accessToken: 'access-token',
      tokenType: 'bearer',
      user: user,
    );

/// In-memory [AuthClient] fake. No network, no Supabase.
///
/// [currentUser] can be seeded for the signed-in render, and [signOut] both
/// clears the user and emits a signed-out event so the StreamBuilder rebuilds.
class _FakeAuthClient implements AuthClient {
  _FakeAuthClient({User? initialUser}) : _currentUser = initialUser;

  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  User? _currentUser;
  final List<String> calls = <String>[];

  /// When set, signInWithPassword returns this response (and seeds the user).
  AuthResponse? signInResponse;

  Future<void> dispose() => _controller.close();

  /// Seeds the current user and pushes a signed-in event onto the stream so
  /// StreamBuilder-based consumers rebuild without a manual trigger.
  void emitSignedIn(User user) {
    _currentUser = user;
    _controller.add(AuthState(AuthChangeEvent.signedIn, _fakeSession(user)));
  }

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  @override
  User? get currentUser => _currentUser;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async =>
      AuthResponse();

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    calls.add('signIn');
    final response = signInResponse;
    if (response != null) {
      _currentUser = response.session?.user ?? response.user;
      final session = response.session;
      if (session != null) {
        _controller.add(AuthState(AuthChangeEvent.signedIn, session));
      }
      return response;
    }
    return AuthResponse();
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _currentUser = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    calls.add('reset');
  }
}

/// Pumps [SettingsScreen] inside a router that provides [service].
///
/// When [realLogin] is true the `/login` route builds the real [LoginScreen]
/// (wired to the same [service]) so an end-to-end round trip can be exercised;
/// otherwise it is a stub that just renders `login-landing`.
Future<void> _pumpSettings(
  WidgetTester tester,
  AuthService service, {
  bool realLogin = false,
}) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => realLogin
            ? LoginScreen(authService: service)
            : const Scaffold(body: Text('login-landing')),
      ),
    ],
  );

  await tester.pumpWidget(
    RepositoryProvider<AuthService>.value(
      value: service,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed out shows the sign-in prompt and routes to /login',
      (tester) async {
    final client = _FakeAuthClient();
    addTearDown(client.dispose);
    final service = AuthService(client);

    await _pumpSettings(tester, service);

    expect(find.text('Sign in to sync across devices'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);

    await tester.tap(find.text('Sign in to sync across devices'));
    await tester.pumpAndSettle();

    expect(find.text('login-landing'), findsOneWidget);
  });

  testWidgets('signed in shows the account email and a Sign out action',
      (tester) async {
    final user = _fakeUser('user-1');
    final client = _FakeAuthClient(initialUser: user);
    addTearDown(client.dispose);
    final service = AuthService(client);

    await _pumpSettings(tester, service);

    expect(find.text('reader@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Sign in to sync across devices'), findsNothing);
  });

  testWidgets('tapping Sign out clears the session and flips the row',
      (tester) async {
    final user = _fakeUser('user-1');
    final client = _FakeAuthClient(initialUser: user);
    addTearDown(client.dispose);
    final service = AuthService(client);

    await _pumpSettings(tester, service);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(client.calls, contains('signOut'));
    // The row reverts to the signed-out prompt once the session clears.
    expect(find.text('Sign in to sync across devices'), findsOneWidget);
    expect(find.text('reader@example.com'), findsNothing);
  });

  testWidgets('reactively flips to the account email when a sign-in is emitted',
      (tester) async {
    final client = _FakeAuthClient();
    addTearDown(client.dispose);
    final service = AuthService(client);

    await _pumpSettings(tester, service);

    // Starts signed out.
    expect(find.text('Sign in to sync across devices'), findsOneWidget);

    // A sign-in happens elsewhere (e.g. another screen) and is pushed onto the
    // stream. No manual rebuild is triggered here.
    client.emitSignedIn(_fakeUser('user-1', email: 'synced@example.com'));
    await tester.pumpAndSettle();

    // The row flips to the account email purely from the stream event.
    expect(find.text('synced@example.com'), findsOneWidget);
    expect(find.text('Sign in to sync across devices'), findsNothing);
  });

  testWidgets(
      'end-to-end: Settings -> /login -> sign in -> pop -> shows the email',
      (tester) async {
    final client = _FakeAuthClient();
    addTearDown(client.dispose);
    // A successful sign-in returns a session (and the fake seeds currentUser
    // and emits a signed-in event, mirroring real Supabase behavior).
    client.signInResponse = AuthResponse(
      session: _fakeSession(_fakeUser('user-1', email: 'roundtrip@example.com')),
    );
    final service = AuthService(client);

    await _pumpSettings(tester, service, realLogin: true);

    // Signed out: tap the account row to navigate to the real login screen.
    expect(find.text('Sign in to sync across devices'), findsOneWidget);
    await tester.tap(find.text('Sign in to sync across devices'));
    await tester.pumpAndSettle();

    // On the LoginScreen now.
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'roundtrip@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Popped back to Settings, which now shows the signed-in account.
    expect(client.calls, contains('signIn'));
    expect(find.text('roundtrip@example.com'), findsOneWidget);
    expect(find.text('Sign in to sync across devices'), findsNothing);
  });
}
