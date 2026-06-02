import 'package:drift/drift.dart';

import '../utils/app_logger.dart';
import 'database.dart';

/// Hard-deletes stale soft-delete tombstones so the local database does not
/// grow without bound (US-003).
///
/// A row is "stale" when its [Entries.deletedAt] (or the equivalent column on
/// the other syncable tables) is older than [retention]. Stale rows have had
/// ample time to propagate, so the physical row is no longer needed.
///
/// TODO(sync): Once cloud sync exists (Phase 2), purging by age alone is no
/// longer safe — a tombstone must also be *confirmed-synced* (or `userId IS
/// NULL`, i.e. never synced and therefore purely local) before it can be hard-
/// deleted, otherwise the delete might never reach other devices. Until then
/// every tombstone is local/unsynced, so age-based purging cannot lose a sync.
class TombstonePurgeService {
  TombstonePurgeService(this._database);

  /// Default age after which a tombstone may be hard-deleted.
  static const Duration defaultRetention = Duration(days: 30);

  static const String _logTag = 'TombstonePurge';

  final AppDatabase _database;

  /// Guards against running more than once per app session.
  bool _hasRun = false;

  /// Runs the purge at most once per app session.
  ///
  /// Subsequent calls are no-ops, so this is safe to invoke unconditionally on
  /// startup. Returns the number of rows purged (0 on the second and later
  /// calls).
  Future<int> runOnce({
    Duration retention = defaultRetention,
    DateTime? now,
  }) async {
    if (_hasRun) return 0;
    _hasRun = true;
    return purge(retention: retention, now: now);
  }

  /// Hard-deletes every tombstone older than [retention] across all syncable
  /// tables. Exposed (separately from [runOnce]) for testing and for callers
  /// that explicitly want to force a purge. Returns the number of rows deleted.
  Future<int> purge({
    Duration retention = defaultRetention,
    DateTime? now,
  }) async {
    final cutoff =
        (now ?? DateTime.now()).millisecondsSinceEpoch - retention.inMilliseconds;

    // A row is stale when deletedAt is set (a tombstone) AND strictly older
    // than the cutoff. Rows newer than the cutoff are kept so they still have
    // time to propagate.
    var deleted = 0;
    await _database.transaction(() async {
      // entry_tags is purged first so cascading FKs never fight the explicit
      // deletes (entry/tag rows it references may also be purged below).
      deleted += await (_database.delete(_database.entryTags)
            ..where((et) => et.deletedAt.isSmallerThanValue(cutoff)))
          .go();
      deleted += await (_database.delete(_database.entries)
            ..where((e) => e.deletedAt.isSmallerThanValue(cutoff)))
          .go();
      deleted += await (_database.delete(_database.tags)
            ..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
          .go();
      deleted += await (_database.delete(_database.categories)
            ..where((c) => c.deletedAt.isSmallerThanValue(cutoff)))
          .go();
    });

    AppLogger.info(
      'Purged $deleted stale tombstone(s) older than '
      '${retention.inDays} day(s).',
      tag: _logTag,
    );

    return deleted;
  }
}
