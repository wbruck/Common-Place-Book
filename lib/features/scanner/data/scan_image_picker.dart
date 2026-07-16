import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/app_logger.dart';
import '../domain/scan_source.dart';

/// Opens the platform camera or gallery picker for a scan and returns the
/// captured image, or null when the user backs out.
///
/// The image is downscaled on capture: ML Kit recognizes book-page text
/// reliably at this size, and smaller inputs keep recognition fast and avoid
/// decoding a full-resolution photo into memory. EXIF metadata is not
/// requested — the photo is only OCR input, and the temporary file the picker
/// writes is deleted once recognition is done (see `deleteScanImage`).
Future<XFile?> pickScanImage(ScanSource source) {
  return ImagePicker().pickImage(
    source: source == ScanSource.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    maxWidth: 2560,
    maxHeight: 2560,
    imageQuality: 90,
    requestFullMetadata: false,
  );
}

/// Recovers a photo the picker lost because Android killed the app while the
/// camera/gallery activity was in the foreground — image_picker's documented
/// lost-data contract, which requires calling `retrieveLostData()` after the
/// app relaunches.
///
/// Returns null when there is nothing to recover. Only Android can lose a
/// pick this way (`retrieveLostData` is unimplemented elsewhere), so every
/// other platform returns null without touching the plugin.
Future<XFile?> retrieveLostScanImage() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }
  try {
    final response = await ImagePicker().retrieveLostData();
    if (response.isEmpty || response.type != RetrieveType.image) {
      return null;
    }
    return response.file;
  } on Exception catch (e) {
    AppLogger.warning(
      'Could not check for a lost scan photo',
      tag: 'Scanner',
      error: e,
    );
    return null;
  }
}
