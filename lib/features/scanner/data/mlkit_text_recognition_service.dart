import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/result.dart';
import '../domain/text_recognition_service.dart';

/// Creates the [TextRecognitionService] for `dart:io` platforms. ML Kit only
/// ships mobile implementations, so [MlKitTextRecognitionService.isSupported]
/// still gates out desktop at runtime.
TextRecognitionService createTextRecognitionService() =>
    MlKitTextRecognitionService();

/// Whether scan entry points should be shown at all: recognition is
/// on-device ML Kit, which only ships Android/iOS implementations.
bool get isScanSupported => Platform.isAndroid || Platform.isIOS;

/// On-device text recognition backed by Google ML Kit (Latin script).
///
/// A [TextRecognizer] is created per call and closed afterwards: scanning is
/// infrequent, and this keeps the native resources from outliving a scan.
class MlKitTextRecognitionService implements TextRecognitionService {
  @override
  bool get isSupported => isScanSupported;

  @override
  Future<Result<String, TextRecognitionError>> recognizeText(
    String imagePath,
  ) async {
    if (!isSupported) {
      return const Failure(TextRecognitionError.unsupportedPlatform);
    }
    final recognizer = TextRecognizer();
    try {
      final recognized =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final text = recognized.text.trim();
      if (text.isEmpty) {
        return const Failure(TextRecognitionError.noTextFound);
      }
      return Success(text);
    } on Exception catch (e, stackTrace) {
      AppLogger.error(
        'Text recognition failed',
        tag: 'Scanner',
        error: e,
        stackTrace: stackTrace,
      );
      return const Failure(TextRecognitionError.recognitionFailed);
    } finally {
      await recognizer.close();
    }
  }
}
