// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui';

/// Web implementation: trigger a browser download of [contents] as [fileName]
/// using a Blob and a temporary anchor element.
///
/// [sharePositionOrigin] is accepted for signature parity with the native
/// implementation (it anchors the iPad share popover) and is ignored on web.
Future<void> saveTextFile({
  required String fileName,
  required String contents,
  Rect? sharePositionOrigin,
}) async {
  final bytes = utf8.encode(contents);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor
    ..click()
    ..remove();
  html.Url.revokeObjectUrl(url);
}
