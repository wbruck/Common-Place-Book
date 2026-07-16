import 'package:common_place_book/core/utils/result.dart';
import 'package:common_place_book/features/scanner/data/mlkit_text_recognition_service.dart';
import 'package:common_place_book/features/scanner/data/unsupported_text_recognition_service.dart';
import 'package:common_place_book/features/scanner/domain/text_recognition_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnsupportedTextRecognitionService', () {
    const service = UnsupportedTextRecognitionService();

    test('reports itself as unsupported', () {
      expect(service.isSupported, isFalse);
    });

    test('fails with unsupportedPlatform without touching the image', () async {
      final result = await service.recognizeText('/no/such/image.jpg');
      expect(
        result,
        const Failure<String, TextRecognitionError>(
          TextRecognitionError.unsupportedPlatform,
        ),
      );
    });
  });

  group('MlKitTextRecognitionService', () {
    // Tests run on the host VM (macOS/Linux), where ML Kit has no
    // implementation. The service must degrade gracefully instead of hitting
    // the missing plugin.
    final service = MlKitTextRecognitionService();

    test('is unsupported off Android/iOS', () {
      expect(service.isSupported, isFalse);
    });

    test('fails with unsupportedPlatform instead of calling the plugin',
        () async {
      final result = await service.recognizeText('/no/such/image.jpg');
      expect(
        result,
        const Failure<String, TextRecognitionError>(
          TextRecognitionError.unsupportedPlatform,
        ),
      );
    });
  });
}
