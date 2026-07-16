import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../../../core/utils/app_logger.dart';

/// Deletes the temporary file the image picker wrote for [image].
///
/// The privacy screen promises scanned photos are never kept, so every scan
/// removes its capture from the app's cache as soon as recognition and the
/// preview read are done with it. A failed delete is only logged: the file
/// sits in the OS-evictable cache, and the scan itself already succeeded.
Future<void> deleteScanImage(XFile image) async {
  try {
    await File(image.path).delete();
  } on Exception catch (e) {
    AppLogger.warning(
      'Could not delete scanned photo',
      tag: 'Scanner',
      error: e,
    );
  }
}
