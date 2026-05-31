import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/database/database.dart';
import 'core/database/database_provider.dart';
import 'core/database/tombstone_purge_service.dart';
import 'core/utils/app_logger.dart';

// Client-safe Supabase config, supplied at build time via --dart-define.
// Only the URL and the anon key are read here; both are safe to ship to the
// client. Server-only secrets (service-role key, DB password) are NEVER
// referenced in client code. `do_not_use_environment` is intentionally
// bypassed here: this is the one sanctioned compile-time config seam.
// ignore: do_not_use_environment
const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
// ignore: do_not_use_environment
const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase before runApp when config is present. Guarded so that
  // a missing/empty --dart-define (e.g. local dev or a test context) does not
  // crash startup: the app stays fully usable logged out (local-first).
  await _initializeSupabase();

  // Initialize the database
  final database = AppDatabase();
  DatabaseProvider.initialize(database);

  // Hard-delete stale soft-delete tombstones once per app session, off the UI
  // thread: this is fire-and-forget so it never blocks first paint, and any
  // failure is logged rather than crashing startup (US-003).
  unawaited(
    TombstonePurgeService(database).runOnce().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      AppLogger.error(
        'Tombstone purge failed on startup',
        tag: 'Startup',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }),
  );

  runApp(const CommonPlaceBookApp());
}

/// Initializes Supabase when client config is available.
///
/// No-op (with a warning) when either value is empty so the app boots and
/// stays usable logged out. Failures are logged rather than crashing startup.
Future<void> _initializeSupabase() async {
  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    AppLogger.warning(
      'Supabase config missing (SUPABASE_URL / SUPABASE_ANON_KEY); '
      'starting in local-only mode. Sign-in will be unavailable.',
      tag: 'Startup',
    );
    return;
  }

  try {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
    AppLogger.info('Supabase initialized', tag: 'Startup');
  } on Object catch (error, stackTrace) {
    AppLogger.error(
      'Supabase initialization failed; continuing in local-only mode',
      tag: 'Startup',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
