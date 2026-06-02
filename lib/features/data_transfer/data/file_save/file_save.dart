// Cross-platform text-file saver. Picks the platform implementation at compile
// time via conditional imports (mirrors `lib/core/database/connection/`).
//
// All implementations expose the same top-level function:
//   Future<void> saveTextFile({required String fileName, required String contents})
//
// - Native (dart:io): writes the file to a temporary directory and hands it to
//   the OS share sheet via `share_plus`.
// - Web (dart:html): triggers a browser download via a Blob + anchor element.
// - Stub: throws UnsupportedError on unsupported platforms.
export 'file_save_stub.dart'
    if (dart.library.io) 'file_save_io.dart'
    if (dart.library.html) 'file_save_web.dart';
