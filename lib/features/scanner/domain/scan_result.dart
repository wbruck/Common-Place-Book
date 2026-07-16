import 'package:flutter/foundation.dart';

/// Result handed back when the scanner is launched in return mode
/// (`/scan?return=true`): the reviewed text and optional source are popped
/// back to the caller instead of being pushed into a new-entry form.
@immutable
class ScanTextResult {
  const ScanTextResult({required this.content, this.source = ''});

  /// The reviewed, recognized text.
  final String content;

  /// Optional author/source the user entered on the review screen.
  final String source;

  /// The entry form's content after landing this scan: appended after a
  /// blank line when [existing] already holds real text, replacing it only
  /// when it is empty or whitespace. Scanned text never clobbers a draft.
  String mergeIntoContent(String existing) =>
      existing.trim().isEmpty ? content : '$existing\n\n$content';

  /// Whether this scan's [source] should fill the entry form's source field:
  /// only when the scan produced one and [existing] is effectively empty, so
  /// a source the user already typed is never overwritten.
  bool shouldFillSource(String existing) =>
      source.isNotEmpty && existing.trim().isEmpty;
}
