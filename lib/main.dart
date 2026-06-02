import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/app.dart';
import 'core/app_info.dart';
import 'core/database/database.dart';
import 'core/database/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the database
  final database = AppDatabase();
  DatabaseProvider.initialize(database);

  // Resolve the app version once so it has a single source of truth.
  final packageInfo = await PackageInfo.fromPlatform();

  runApp(
    CommonPlaceBookApp(appInfo: AppInfo(version: packageInfo.version)),
  );
}
