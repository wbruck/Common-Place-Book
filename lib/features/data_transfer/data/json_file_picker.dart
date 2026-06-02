import 'dart:convert';

import 'package:file_picker/file_picker.dart';

/// Opens the platform file picker (filtered to `.json` files) and returns the
/// selected file's contents decoded as UTF-8, or `null` if the user cancelled
/// or no readable bytes were returned.
///
/// `withData: true` is required so `bytes` are populated on every platform
/// (notably web, where there is no file path).
Future<String?> pickJsonFileContents() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    withData: true,
  );

  if (result == null || result.files.isEmpty) {
    return null;
  }

  final bytes = result.files.first.bytes;
  if (bytes == null) {
    return null;
  }

  // Decode permissively so a non-UTF-8 file (e.g. a binary file renamed to
  // `.json`, or text in another encoding) never throws an unhandled
  // [FormatException] here. Any resulting garbage simply fails JSON parsing in
  // the import path, which the callers surface as a user-facing error.
  return utf8.decode(bytes, allowMalformed: true);
}
