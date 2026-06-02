import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/app.dart';
import 'core/app_info.dart';
import 'core/database/database.dart';
import 'core/database/database_provider.dart';
import 'core/database/tombstone_purge_service.dart';
import 'core/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Resolve the app version once so it has a single source of truth.
  final packageInfo = await PackageInfo.fromPlatform();

  runApp(
    CommonPlaceBookApp(appInfo: AppInfo(version: packageInfo.version)),
  );
}
