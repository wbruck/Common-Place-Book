import '../../../core/utils/result.dart';

/// Ways text recognition can fail, surfaced to the UI layer.
enum TextRecognitionError {
  /// Recognition is not available on this platform (web, desktop).
  unsupportedPlatform,

  /// The image was processed but contained no readable text.
  noTextFound,

  /// Recognition threw; details are logged, not surfaced.
  recognitionFailed,
}

/// Extracts text from an image of a physical source (book page, sign, etc.).
///
/// Implementations run entirely on-device: images are never uploaded and are
/// not retained after recognition.
abstract class TextRecognitionService {
  /// Whether recognition can run on the current platform. UI entry points
  /// should be hidden when false.
  bool get isSupported;

  /// Recognizes text in the image file at [imagePath].
  ///
  /// Returns the raw recognized text (blocks separated by newlines) on
  /// success; cleanup/reflow is the caller's concern.
  Future<Result<String, TextRecognitionError>> recognizeText(String imagePath);
}
