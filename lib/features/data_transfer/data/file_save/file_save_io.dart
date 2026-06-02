import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'file_save_result.dart';

/// Native implementation: write [contents] to a temporary file named [fileName]
/// and present it through the OS share sheet via `share_plus`.
///
/// Uses the `Share.shareXFiles` API from share_plus v10. Returns
/// [FileSaveOutcome.dismissed] when the user closes the share sheet without
/// saving/sharing, otherwise [FileSaveOutcome.completed].
///
/// [sharePositionOrigin] anchors the share popover on iPad. share_plus requires
/// it on iPads; omitting it causes the share sheet to fail or crash there, so
/// callers should pass the global rect of the tapped widget.
Future<FileSaveOutcome> saveTextFile({
  required String fileName,
  required String contents,
  Rect? sharePositionOrigin,
}) async {
  final tempDir = await getTemporaryDirectory();
  final filePath = p.join(tempDir.path, fileName);
  final file = File(filePath);
  await file.writeAsString(contents);

  final result = await Share.shareXFiles(
    [XFile(filePath, mimeType: 'application/json')],
    subject: fileName,
    sharePositionOrigin: sharePositionOrigin,
  );

  return result.status == ShareResultStatus.dismissed
      ? FileSaveOutcome.dismissed
      : FileSaveOutcome.completed;
}
