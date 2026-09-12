// Regression test: when the app is cold-started straight into the new-entry
// form (text shared in from another Android app via the share sheet), the
// home screen — which normally triggers the TagsCubit load — never builds. The
// form must load the user's existing tags itself so the tag picker is not
// empty.
//
// Runs against an in-memory database; the router's start location is set the
// same way `main()` does it for a share launch.

import 'package:common_place_book/app/app.dart';
import 'package:common_place_book/app/router.dart';
import 'package:common_place_book/core/app_info.dart';
import 'package:common_place_book/core/database/database.dart';
import 'package:common_place_book/core/database/database_provider.dart';
import 'package:common_place_book/features/entries/data/repositories/local_entry_repository.dart';
import 'package:common_place_book/features/settings/data/local_settings_repository.dart';
import 'package:common_place_book/features/tags/data/repositories/local_tag_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_notification_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    DatabaseProvider.initialize(db);
  });

  tearDown(() async {
    await DatabaseProvider.close();
  });

  testWidgets(
      'share cold-start opens the pre-filled form with existing tags listed',
      (tester) async {
    // Tags created on an earlier run, before this share launch.
    final tagRepository = LocalTagRepository(database: db);
    await tagRepository.createTag(name: 'Stoicism');
    await tagRepository.createTag(name: 'Poetry');

    // Mirror main(): the share becomes the router's start location, set
    // before appRouter (a lazy top-level final) is first touched.
    shareLaunchLocation = shareTargetLocation({'text': 'A shared quote.'});

    await tester.pumpWidget(
      CommonPlaceBookApp(
        appInfo: const AppInfo(version: 'test'),
        settingsRepository: LocalSettingsRepository(db),
        entryRepository: LocalEntryRepository(database: db),
        notificationService: FakeNotificationService(supported: false),
      ),
    );
    await tester.pumpAndSettle();

    // Landed on the form with the shared text, not on the home screen...
    expect(find.text('A shared quote.'), findsOneWidget);
    expect(find.text('Good morning'), findsNothing);
    expect(find.text('Good afternoon'), findsNothing);
    expect(find.text('Good evening'), findsNothing);

    // ...and the existing tags are offered in the picker.
    expect(find.text('Stoicism'), findsOneWidget);
    expect(find.text('Poetry'), findsOneWidget);
    expect(find.text('New tag'), findsOneWidget);
  });
}
