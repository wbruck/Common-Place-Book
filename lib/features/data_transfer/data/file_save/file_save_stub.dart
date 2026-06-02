import 'dart:ui';

/// Fallback implementation used when neither `dart:io` nor `dart:html` is
/// available. Saving a text file is not supported on such a platform.
///
/// [sharePositionOrigin] is accepted only for signature parity with the other
/// implementations; this stub never uses it.
Future<void> saveTextFile({
  required String fileName,
  required String contents,
  Rect? sharePositionOrigin,
}) async {
  throw UnsupportedError('File export is not supported on this platform.');
}
