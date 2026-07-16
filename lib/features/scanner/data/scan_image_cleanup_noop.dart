import 'package:image_picker/image_picker.dart';

/// No-op for platforms without `dart:io` (web): picked images are held in
/// memory, so there is no temporary file to delete.
Future<void> deleteScanImage(XFile image) async {}
