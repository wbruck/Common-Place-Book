import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../data/scan_image_cleanup.dart';
import '../../data/scan_image_picker.dart';
import '../../domain/scan_source.dart';
import '../../domain/scan_text_cleaner.dart';
import '../../domain/text_recognition_service.dart';

// ============ States ============

sealed class ScanState {
  const ScanState();
}

class ScanInitial extends ScanState {
  const ScanInitial();
}

/// The platform camera/gallery picker is open.
class ScanCapturing extends ScanState {
  const ScanCapturing();
}

/// A photo was taken and on-device recognition is running.
class ScanRecognizing extends ScanState {
  const ScanRecognizing();
}

/// The user backed out of the picker on the *initial* capture without taking
/// a photo; the screen should close itself. Backing out of a retake instead
/// re-emits the review/failure state the retake was launched from.
class ScanCancelled extends ScanState {
  const ScanCancelled();
}

/// Recognition succeeded; the text is ready for review and editing.
class ScanReview extends ScanState {
  const ScanReview({required this.text, this.imageBytes, this.suggestedSource});

  /// Recognized text, cleaned and reflowed into natural paragraphs.
  final String text;

  /// The scanned photo for the review preview; null if it could not be
  /// re-read (the preview is optional, the text is what matters).
  final Uint8List? imageBytes;

  /// Attribution lifted from a trailing "— Author" line, offered as the
  /// entry's source; null when no attribution line was detected.
  final String? suggestedSource;
}

/// Why a scan attempt ended without text to review.
enum ScanFailureReason {
  /// The camera/gallery picker threw (e.g. camera permission denied).
  captureFailed,

  /// The photo was processed but no readable text was found.
  noTextFound,

  /// Text recognition threw; details are logged.
  recognitionFailed,

  /// Scanning is not available on this platform.
  unsupportedPlatform,
}

class ScanFailed extends ScanState {
  const ScanFailed(this.reason);
  final ScanFailureReason reason;
}

// ============ Cubit ============

/// Picks an image for scanning; injectable so tests can bypass the platform
/// picker. Defaults to [pickScanImage].
typedef PickScanImage = Future<XFile?> Function(ScanSource source);

/// Deletes the temporary photo a scan captured; injectable so tests can
/// observe the cleanup. Defaults to [deleteScanImage].
typedef DeleteScanImage = Future<void> Function(XFile image);

/// Drives the scan flow: capture an image, recognize its text on-device,
/// then hand the result to the review UI.
class ScanCubit extends Cubit<ScanState> {
  ScanCubit({
    required TextRecognitionService recognitionService,
    PickScanImage? pickImage,
    DeleteScanImage? deleteImage,
  })  : _recognitionService = recognitionService,
        _pickImage = pickImage ?? pickScanImage,
        _deleteImage = deleteImage ?? deleteScanImage,
        super(const ScanInitial());

  final TextRecognitionService _recognitionService;
  final PickScanImage _pickImage;
  final DeleteScanImage _deleteImage;

  /// Runs one capture-and-recognize attempt from [source]. Also used to
  /// retake after a failure or from the review screen; backing out of the
  /// picker during such a retake returns to what the user was looking at
  /// instead of cancelling the whole flow.
  Future<void> scan(ScanSource source) async {
    final previous = state;
    emit(const ScanCapturing());

    final XFile? image;
    try {
      image = await _pickImage(source);
    } on Exception catch (e, stackTrace) {
      AppLogger.error(
        'Image capture failed',
        tag: 'Scanner',
        error: e,
        stackTrace: stackTrace,
      );
      if (!isClosed) emit(const ScanFailed(ScanFailureReason.captureFailed));
      return;
    }
    if (isClosed) return;

    if (image == null) {
      // Only the initial capture cancels the flow. On a retake the user
      // already has a review (or failure) on screen conceptually — their
      // edits live in the screen's controllers — so hand that state back.
      emit(
        switch (previous) {
          ScanReview() || ScanFailed() => previous,
          _ => const ScanCancelled(),
        },
      );
      return;
    }

    await _recognize(image);
  }

  /// Recognizes [image] directly, without opening a picker — used to resume
  /// a scan whose photo was recovered after Android killed the app while the
  /// camera was open (see `retrieveLostScanImage`).
  Future<void> recognizeImage(XFile image) => _recognize(image);

  Future<void> _recognize(XFile image) async {
    emit(const ScanRecognizing());
    final result = await _recognitionService.recognizeText(image.path);

    // The review preview needs the file's bytes, so read them before the
    // capture file is deleted below.
    final bytes = result is Success<String, TextRecognitionError>
        ? await _tryReadBytes(image)
        : null;
    // The privacy screen promises scanned photos are never kept: the picker
    // wrote the capture into the app's cache, so remove it as soon as
    // recognition and the preview read are done with it.
    await _deleteImage(image);
    if (isClosed) return;

    switch (result) {
      case Success(value: final text):
        final cleaned = cleanScannedText(text);
        emit(
          ScanReview(
            text: cleaned.text,
            imageBytes: bytes,
            suggestedSource: cleaned.suggestedSource,
          ),
        );
      case Failure(error: final error):
        emit(
          ScanFailed(
            switch (error) {
              TextRecognitionError.noTextFound => ScanFailureReason.noTextFound,
              TextRecognitionError.recognitionFailed =>
                ScanFailureReason.recognitionFailed,
              TextRecognitionError.unsupportedPlatform =>
                ScanFailureReason.unsupportedPlatform,
            },
          ),
        );
    }
  }

  /// The preview image is nice-to-have; a read failure must not sink a scan
  /// whose text already came back fine.
  Future<Uint8List?> _tryReadBytes(XFile image) async {
    try {
      return await image.readAsBytes();
    } on Exception catch (e) {
      AppLogger.warning('Could not read scan preview', tag: 'Scanner', error: e);
      return null;
    }
  }
}
