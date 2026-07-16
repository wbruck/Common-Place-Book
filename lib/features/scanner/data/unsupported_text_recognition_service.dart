import '../../../core/utils/result.dart';
import '../domain/text_recognition_service.dart';

/// Creates the [TextRecognitionService] for platforms without `dart:io`
/// (web): recognition is unavailable there.
TextRecognitionService createTextRecognitionService() =>
    const UnsupportedTextRecognitionService();

/// Whether scan entry points should be shown at all: never on platforms
/// without `dart:io` — ML Kit cannot run there.
bool get isScanSupported => false;

/// No-op implementation for platforms where ML Kit is unavailable.
class UnsupportedTextRecognitionService implements TextRecognitionService {
  /// Const so the factory can hand out a shared instance.
  const UnsupportedTextRecognitionService();

  @override
  bool get isSupported => false;

  @override
  Future<Result<String, TextRecognitionError>> recognizeText(
    String imagePath,
  ) async =>
      const Failure(TextRecognitionError.unsupportedPlatform);
}
