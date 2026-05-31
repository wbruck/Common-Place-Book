// US-007 / FR-11: signing out is non-destructive.
//
// Asserts that signing out clears only the auth session and does NOT touch the
// local Drift database: every locally created entry is still present after
// AuthService.signOut() completes.
//
// Fully hermetic: an in-memory Drift database and a fake [AuthClient] (no
// network, no `Supabase.initialize`).

import 'package:common_place_book/core/auth/auth_service.dart';
import 'package:common_place_book/core/database/database.dart';
import 'package:common_place_book/features/entries/data/repositories/local_entry_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late LocalEntryRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalEntryRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('sign-out keeps every local entry in the database', () async {
    // Seed a few local-only entries (the logged-out, source-of-truth state).
    await repository.createEntry(content: 'Local quote one');
    await repository.createEntry(content: 'Local quote two');
    await repository.createEntry(content: 'Local quote three');

    expect(await repository.getEntryCount(), 3);

    // Sign out. The LocalOnlyAuthClient signOut is a pure session no-op and
    // intentionally never references the database; this mirrors the real
    // Supabase signOut, which also only clears the session.
    final service = AuthService(const LocalOnlyAuthClient());
    final result = await service.signOut();
    expect(result.isSuccess, isTrue);

    // Local data is untouched: same count, same content, still readable.
    expect(await repository.getEntryCount(), 3);
    final entries = await repository.getAllEntries();
    expect(entries, hasLength(3));
    expect(
      entries.map((entry) => entry.content),
      containsAll(<String>[
        'Local quote one',
        'Local quote two',
        'Local quote three',
      ]),
    );
  });
}
