// Smoke test for the Common Place Book app.
//
// Builds the real root widget (CommonPlaceBookApp) against an in-memory
// database and verifies it boots without throwing.

import 'package:common_place_book/app/app.dart';
import 'package:common_place_book/core/app_info.dart';
import 'package:common_place_book/core/database/database.dart';
import 'package:common_place_book/core/database/database_provider.dart';
import 'package:common_place_book/features/settings/data/local_settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    // Use an in-memory database so tests don't touch the platform connection.
    database = AppDatabase.forTesting(NativeDatabase.memory());
    DatabaseProvider.initialize(database);
  });

  tearDown(() async {
    await DatabaseProvider.close();
  });

  testWidgets('App boots and renders a MaterialApp', (tester) async {
    await tester.pumpWidget(
      CommonPlaceBookApp(
        appInfo: const AppInfo(version: 'test'),
        settingsRepository: LocalSettingsRepository(database),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
