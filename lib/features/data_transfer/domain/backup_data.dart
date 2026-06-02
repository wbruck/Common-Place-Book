// Plain data holders for the backup payload, kept free of Drift's generated
// row types so the BackupRepository boundary does not leak persistence details.
// All timestamps are raw milliseconds since epoch.

class BackupData {
  const BackupData({
    required this.schemaVersion,
    required this.categories,
    required this.tags,
    required this.entries,
    required this.entryTags,
  });

  /// The database schema version the backup was produced against.
  final int schemaVersion;
  final List<BackupCategory> categories;
  final List<BackupTag> tags;
  final List<BackupEntry> entries;
  final List<BackupEntryTag> entryTags;
}

class BackupCategory {
  const BackupCategory({
    required this.id,
    required this.name,
    required this.parentId,
    required this.icon,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? parentId;
  final String? icon;
  final int createdAt;
}

class BackupTag {
  const BackupTag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? color;
  final int createdAt;
}

class BackupEntry {
  const BackupEntry({
    required this.id,
    required this.content,
    required this.source,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    required this.lastViewedAt,
    required this.viewCount,
    required this.isFavorite,
  });

  final String id;
  final String content;
  final String? source;
  final String? categoryId;
  final int createdAt;
  final int updatedAt;
  final int? lastViewedAt;
  final int viewCount;
  final bool isFavorite;
}

class BackupEntryTag {
  const BackupEntryTag({required this.entryId, required this.tagId});

  final String entryId;
  final String tagId;
}

/// Number of rows written per table during an import.
class ImportSummary {
  const ImportSummary({
    required this.categories,
    required this.tags,
    required this.entries,
    required this.entryTags,
  });

  final int categories;
  final int tags;
  final int entries;
  final int entryTags;

  @override
  String toString() =>
      'ImportSummary(categories: $categories, tags: $tags, '
      'entries: $entries, entryTags: $entryTags)';
}

/// Why an export/import failed, surfaced through a [Result] failure.
enum DataTransferErrorKind {
  /// The chosen file is not a valid or compatible backup.
  invalidBackup,

  /// An unexpected I/O or database error; the operation did not complete.
  unexpected,
}

class DataTransferFailure {
  const DataTransferFailure(this.kind, this.message);

  const DataTransferFailure.invalidBackup(String message)
      : this(DataTransferErrorKind.invalidBackup, message);

  const DataTransferFailure.unexpected(String message)
      : this(DataTransferErrorKind.unexpected, message);

  final DataTransferErrorKind kind;
  final String message;

  @override
  String toString() => 'DataTransferFailure($kind: $message)';
}
