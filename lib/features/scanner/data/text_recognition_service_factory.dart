// Cross-platform text-recognition factory. Picks the platform implementation
// at compile time via conditional exports (mirrors
// `lib/features/data_transfer/data/file_save/`).
//
// Both implementations expose the same top-level members:
//   TextRecognitionService createTextRecognitionService()
//   bool get isScanSupported — the single platform gate for showing scan
//   entry points in the UI, so the support rule lives in exactly one place
//   per platform.
//
// - dart:io (mobile/desktop): ML Kit on-device recognition; `isSupported` is
//   only true on Android/iOS, where ML Kit ships implementations.
// - Everything else (web): stub whose `isSupported` is false and whose
//   `recognizeText` fails with `unsupportedPlatform`.
export 'unsupported_text_recognition_service.dart'
    if (dart.library.io) 'mlkit_text_recognition_service.dart';
