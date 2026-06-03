import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/discovery/presentation/screens/discovery_screen.dart';
import '../features/entries/presentation/screens/entry_detail_screen.dart';
import '../features/entries/presentation/screens/entry_form_screen.dart';
import '../features/entries/presentation/screens/home_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/tags/presentation/screens/tags_screen.dart';

/// Key for GoRouter's root navigator. Exposed so app-level overlays (e.g. the
/// first-run welcome dialog) can obtain a context that sits *below* the
/// navigator — `MaterialApp.router`'s `builder` context sits above it, where
/// `showDialog` cannot find a Navigator.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/entry/new',
      name: 'newEntry',
      builder: (context, state) => const EntryFormScreen(),
    ),
    GoRoute(
      path: '/entry/:id',
      name: 'entryDetail',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EntryDetailScreen(entryId: id);
      },
    ),
    GoRoute(
      path: '/entry/:id/edit',
      name: 'editEntry',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EntryFormScreen(entryId: id);
      },
    ),
    GoRoute(
      path: '/discover',
      name: 'discover',
      builder: (context, state) => const DiscoveryScreen(),
    ),
    GoRoute(
      path: '/tags',
      name: 'tags',
      builder: (context, state) => const TagsScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
