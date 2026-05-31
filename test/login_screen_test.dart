// Widget tests for US-005: LoginScreen.
//
// Fully hermetic: a fake [AuthClient] is injected into a real [AuthService],
// which is in turn injected into [LoginScreen]. No real network call and no
// `Supabase.initialize` ever run.

import 'dart:async';

import 'package:common_place_book/core/auth/auth_service.dart';
import 'package:common_place_book/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  /// When set, signUp/signInWithPassword return this response.
  AuthResponse? responseToReturn;

  /// Records the operations the screen invoked, for assertions.
  final List<String> calls = <String>[];

  Future<void> dispose() => _controller.close();

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  @override
  User? get currentUser => _currentUser;

  Future<AuthResponse> _runOrThrow(String op) async {
    calls.add(op);
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
      _runOrThrow('signUp');

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) =>
      _runOrThrow('signIn');

  @override
  Future<void> signOut() async {
    calls.add('signOut');
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    calls.add('reset');
    final error = errorToThrow;
    if (error != null) {
      throw error;
    }
  }
}

/// Pumps [LoginScreen] inside a router so `context.pop`/`go` resolve. A second
/// `/` route acts as the post-login landing target.
Future<void> _pumpLoginScreen(
  WidgetTester tester,
  AuthService service,
) async {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Text('home-landing')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(authService: service),
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
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

  testWidgets('shows inline validation errors for bad email and short password',
      (tester) async {
    await _pumpLoginScreen(tester, service);

    await tester.enterText(
      find.byType(TextFormField).first,
      'not-an-email',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      '123',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );
    // The backend was never called because validation failed.
    expect(client.calls, isEmpty);
  });

  testWidgets('successful sign-in calls the service and pops the screen',
      (tester) async {
    client.responseToReturn =
        AuthResponse(session: _fakeSession(_fakeUser('signed-in')));

    await _pumpLoginScreen(tester, service);

    await tester.enterText(
      find.byType(TextFormField).first,
      'user@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'password123',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(client.calls, contains('signIn'));
    // After a successful sign-in the login route is popped and we land home.
    expect(find.text('home-landing'), findsOneWidget);
  });

  testWidgets('backend error surfaces a readable message, not a stack trace',
      (tester) async {
    client.errorToThrow = const AuthException(
      'Invalid login credentials',
      code: 'invalid_credentials',
    );

    await _pumpLoginScreen(tester, service);

    await tester.enterText(
      find.byType(TextFormField).first,
      'user@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'wrongpassword',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(client.calls, contains('signIn'));
    expect(find.text('Invalid login credentials'), findsOneWidget);
    // Still on the login screen (no navigation on failure).
    expect(find.text('home-landing'), findsNothing);
  });

  testWidgets('toggling to sign-up calls signUp on submit', (tester) async {
    client.responseToReturn =
        AuthResponse(user: _fakeUser('new-user'));

    await _pumpLoginScreen(tester, service);

    // Switch to create-account mode.
    await tester.tap(
      find.text("Don't have an account? Create one"),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'new@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'password123',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(client.calls, contains('signUp'));
    // Forgot-password link is sign-in only.
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('forgot-password requires a valid email first', (tester) async {
    await _pumpLoginScreen(tester, service);

    // No email entered yet.
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(client.calls, isEmpty);
    expect(
      find.textContaining('Enter your email above first'),
      findsOneWidget,
    );
  });

  testWidgets('forgot-password sends a reset for a valid email',
      (tester) async {
    await _pumpLoginScreen(tester, service);

    await tester.enterText(
      find.byType(TextFormField).first,
      'user@example.com',
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(client.calls, contains('reset'));
    expect(
      find.textContaining('reset link is on its way'),
      findsOneWidget,
    );
  });
}
