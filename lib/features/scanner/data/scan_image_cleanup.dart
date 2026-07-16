// Cross-platform cleanup for the temporary photo a scan captures. Picks the
// platform implementation at compile time via conditional exports (mirrors
// `text_recognition_service_factory.dart`).
//
// Both implementations expose the same top-level function:
//   Future<void> deleteScanImage(XFile image)
//
// - dart:io (mobile/desktop): the picker wrote the capture to the app's
//   cache/tmp directory, so the file is deleted from disk.
// - Everything else (web): picked images live in memory; nothing to delete.
export 'scan_image_cleanup_noop.dart'
    if (dart.library.io) 'scan_image_cleanup_io.dart';
