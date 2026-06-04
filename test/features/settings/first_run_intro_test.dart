// Tests for the one-time first-visit welcome:
//   - LocalSettingsRepository persists the "intro seen" flag (defaults to
//     false, flips to true via markIntroSeen) through the key/value `settings`
//     table.
//   - CommonPlaceBookApp shows the About dialog once on first launch
//     (showIntroOnLaunch: true) and marks it seen, and shows nothing when the
//     flag says the user has already seen it.
//
// Runs against an in-memory database so nothing touches the platform
// connection.

import 'package:common_place_book/app/app.dart';
import 'package:common_place_book/core/app_info.dart';
import 'package:common_place_book/core/database/database.dart';
import 'package:common_place_book/core/database/database_provider.dart';
import 'package:common_place_book/features/settings/data/local_settings_repository.dart';
import 'package:common_place_book/features/settings/domain/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    DatabaseProvider.initialize(db);
    repository = LocalSettingsRepository(db);
  });

  tearDown(() async {
    await DatabaseProvider.close();
  });

  group('LocalSettingsRepository intro flag', () {
    test('defaults to not-seen when nothing is persisted', () async {
      expect(await repository.hasSeenIntro(), isFalse);
    });

    test('markIntroSeen flips the flag and persists it', () async {
      await repository.markIntroSeen();
      expect(await repository.hasSeenIntro(), isTrue);
    });

    test('marking seen twice keeps a single settings row (upsert)', () async {
      await repository.markIntroSeen();
      await repository.markIntroSeen();

      expect(await repository.hasSeenIntro(), isTrue);
      final rows = await db.select(db.settings).get();
      expect(rows.length, 1);
    });
  });

  group('CommonPlaceBookApp first-run welcome', () {
    testWidgets('shows the About dialog and marks it seen on first launch',
        (tester) async {
      await tester.pumpWidget(
        CommonPlaceBookApp(
          appInfo: const AppInfo(version: 'test'),
          settingsRepository: repository,
          showIntroOnLaunch: true,
        ),
      );
      await tester.pumpAndSettle();

      // The welcome dialog is on screen (the Swift epigraph is unique to it),
      // with the first-run "Get started" action rather than "Close".
      expect(find.text('— Jonathan Swift'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Close'), findsNothing);
      // ...and the visit was recorded so it will not appear again.
      expect(await repository.hasSeenIntro(), isTrue);
    });

    testWidgets('shows nothing when the user has already seen the intro',
        (tester) async {
      await tester.pumpWidget(
        CommonPlaceBookApp(
          appInfo: const AppInfo(version: 'test'),
          settingsRepository: repository,
          // showIntroOnLaunch defaults to false (returning visitor).
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('— Jonathan Swift'), findsNothing);
    });
  });
}
