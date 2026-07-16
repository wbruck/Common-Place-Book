import 'dart:typed_data';

import 'package:common_place_book/core/utils/result.dart';
import 'package:common_place_book/features/scanner/domain/scan_source.dart';
import 'package:common_place_book/features/scanner/domain/text_recognition_service.dart';
import 'package:common_place_book/features/scanner/presentation/bloc/scan_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _FakeRecognitionService implements TextRecognitionService {
  _FakeRecognitionService(this.result);
  final Result<String, TextRecognitionError> result;
  String? lastImagePath;

  @override
  bool get isSupported => true;

  @override
  Future<Result<String, TextRecognitionError>> recognizeText(
    String imagePath,
  ) async {
    lastImagePath = imagePath;
    return result;
  }
}

void main() {
  final imageBytes = Uint8List.fromList([1, 2, 3]);
  final image = XFile.fromData(imageBytes, path: '/scan/photo.jpg');

  /// Runs a scan and returns every state the cubit emitted. Deleted capture
  /// paths are recorded into [deletedPaths] when provided.
  Future<List<ScanState>> statesFor({
    required TextRecognitionService recognition,
    required Future<XFile?> Function(ScanSource) pickImage,
    List<String>? deletedPaths,
  }) async {
    final cubit = ScanCubit(
      recognitionService: recognition,
      pickImage: pickImage,
      deleteImage: (image) async => deletedPaths?.add(image.path),
    );
    final states = <ScanState>[];
    final subscription = cubit.stream.listen(states.add);
    await cubit.scan(ScanSource.camera);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    await cubit.close();
    return states;
  }

  test('successful scan ends in review with text and preview bytes', () async {
    final recognition = _FakeRecognitionService(const Success('found text'));
    final states = await statesFor(
      recognition: recognition,
      pickImage: (_) async => image,
    );

    expect(states, [
      isA<ScanCapturing>(),
      isA<ScanRecognizing>(),
      isA<ScanReview>(),
    ]);
    final review = states.last as ScanReview;
    expect(review.text, 'found text');
    expect(review.imageBytes, imageBytes);
    expect(recognition.lastImagePath, '/scan/photo.jpg');
  });

  test('hard-wrapped OCR text is reflowed onto one line for review', () async {
    final states = await statesFor(
      recognition: _FakeRecognitionService(
        const Success(
          'The happiness of your life depends upon the quality\n'
          'of your thoughts.',
        ),
      ),
      pickImage: (_) async => image,
    );

    final review = states.last as ScanReview;
    expect(
      review.text,
      'The happiness of your life depends upon the quality '
      'of your thoughts.',
    );
    expect(review.suggestedSource, isNull);
  });

  test('a trailing attribution line becomes the suggested source', () async {
    final states = await statesFor(
      recognition: _FakeRecognitionService(
        const Success(
          'Waste no more time arguing about what a good man should be. '
          'Be one.\n— Marcus Aurelius, Meditations',
        ),
      ),
      pickImage: (_) async => image,
    );

    final review = states.last as ScanReview;
    expect(
      review.text,
      'Waste no more time arguing about what a good man should be. Be one.',
    );
    expect(review.suggestedSource, 'Marcus Aurelius, Meditations');
  });

  test('dismissing the picker cancels the scan without recognizing', () async {
    final recognition = _FakeRecognitionService(const Success('unused'));
    final states = await statesFor(
      recognition: recognition,
      pickImage: (_) async => null,
    );

    expect(states, [isA<ScanCapturing>(), isA<ScanCancelled>()]);
    expect(recognition.lastImagePath, isNull);
  });

  test('cancelling a retake returns to the review instead of closing',
      () async {
    var picks = 0;
    final cubit = ScanCubit(
      recognitionService: _FakeRecognitionService(const Success('found text')),
      pickImage: (_) async => ++picks == 1 ? image : null,
      deleteImage: (_) async {},
    );
    final states = <ScanState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.scan(ScanSource.camera);
    final review = cubit.state;
    expect(review, isA<ScanReview>());

    // Retake, then back out of the picker: the prior review comes back and
    // the flow is never cancelled.
    await cubit.scan(ScanSource.camera);
    await Future<void>.delayed(Duration.zero);
    expect(states.last, same(review));
    expect(states.whereType<ScanCancelled>(), isEmpty);

    await subscription.cancel();
    await cubit.close();
  });

  test('cancelling a retake after a failure returns to that failure',
      () async {
    var picks = 0;
    final cubit = ScanCubit(
      recognitionService: _FakeRecognitionService(
        const Failure(TextRecognitionError.noTextFound),
      ),
      pickImage: (_) async => ++picks == 1 ? image : null,
      deleteImage: (_) async {},
    );

    await cubit.scan(ScanSource.camera);
    final failed = cubit.state;
    expect(failed, isA<ScanFailed>());

    await cubit.scan(ScanSource.camera);
    expect(cubit.state, same(failed));

    await cubit.close();
  });

  test('recognizeImage skips the picker and reviews the given photo',
      () async {
    final cubit = ScanCubit(
      recognitionService: _FakeRecognitionService(const Success('recovered')),
      pickImage: (_) async => fail('the picker must not open for a recovery'),
      deleteImage: (_) async {},
    );
    final states = <ScanState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.recognizeImage(image);
    await Future<void>.delayed(Duration.zero);
    expect(states, [isA<ScanRecognizing>(), isA<ScanReview>()]);
    expect((states.last as ScanReview).text, 'recovered');

    await subscription.cancel();
    await cubit.close();
  });

  test('the capture file is deleted once recognition succeeds', () async {
    final deletedPaths = <String>[];
    await statesFor(
      recognition: _FakeRecognitionService(const Success('found text')),
      pickImage: (_) async => image,
      deletedPaths: deletedPaths,
    );
    expect(deletedPaths, ['/scan/photo.jpg']);
  });

  test('the capture file is deleted even when recognition fails', () async {
    final deletedPaths = <String>[];
    await statesFor(
      recognition: _FakeRecognitionService(
        const Failure(TextRecognitionError.noTextFound),
      ),
      pickImage: (_) async => image,
      deletedPaths: deletedPaths,
    );
    expect(deletedPaths, ['/scan/photo.jpg']);
  });

  test('a photo without readable text fails with noTextFound', () async {
    final states = await statesFor(
      recognition: _FakeRecognitionService(
        const Failure(TextRecognitionError.noTextFound),
      ),
      pickImage: (_) async => image,
    );

    expect(states.last, isA<ScanFailed>());
    expect(
      (states.last as ScanFailed).reason,
      ScanFailureReason.noTextFound,
    );
  });

  test('a picker exception fails with captureFailed', () async {
    final recognition = _FakeRecognitionService(const Success('unused'));
    final states = await statesFor(
      recognition: recognition,
      pickImage: (_) async => throw Exception('camera unavailable'),
    );

    expect(states, [isA<ScanCapturing>(), isA<ScanFailed>()]);
    expect(
      (states.last as ScanFailed).reason,
      ScanFailureReason.captureFailed,
    );
    expect(recognition.lastImagePath, isNull);
  });

  test('recognition errors map onto their scan failure reasons', () async {
    final cases = {
      TextRecognitionError.recognitionFailed:
          ScanFailureReason.recognitionFailed,
      TextRecognitionError.unsupportedPlatform:
          ScanFailureReason.unsupportedPlatform,
    };
    for (final entry in cases.entries) {
      final states = await statesFor(
        recognition: _FakeRecognitionService(Failure(entry.key)),
        pickImage: (_) async => image,
      );
      expect((states.last as ScanFailed).reason, entry.value);
    }
  });
}
