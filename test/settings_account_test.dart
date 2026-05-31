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

  Future<void> dispose() => _controller.close();

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
  }) async =>
      AuthResponse();

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

/// Pumps [SettingsScreen] inside a router that provides [service] and a stub
/// `/login` route so the sign-in tap can resolve.
Future<void> _pumpSettings(
  WidgetTester tester,
  AuthService service,
) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const Scaffold(body: Text('login-landing')),
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
}
