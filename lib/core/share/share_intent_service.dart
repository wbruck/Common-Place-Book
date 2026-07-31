import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Receives text shared into the app from other Android apps via the system
/// share sheet (ACTION_SEND, declared in AndroidManifest.xml).
///
/// The platform side lives in MainActivity.kt on the matching channel. Two
/// delivery paths exist:
/// - Cold start: the share launches the app; [getInitialShare] returns it.
/// - Warm share: the app is already running (singleTop), the share arrives via
///   onNewIntent and is pushed to the handler set with [setOnShareReceived].
///
/// The returned maps use the same `text` / `title` keys as the web PWA share
/// target, so both feed [shareTargetLocation] unchanged.
class ShareIntentService {
  static const _channel = MethodChannel('com.example.common_place_book/share');

  /// Uses [defaultTargetPlatform] (not dart:io Platform) so tests can override
  /// the platform; in widget tests it already defaults to Android.
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The share that launched the app, or null when the app was not launched
  /// from the share sheet. The platform side consumes the intent, so this
  /// returns the share at most once per launch.
  Future<Map<String, String>?> getInitialShare() async {
    if (!isSupported) return null;
    return _channel.invokeMapMethod<String, String>('getInitialShare');
  }

  /// Registers [handler] for shares delivered while the app is running.
  void setOnShareReceived(void Function(Map<String, String> params) handler) {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shareReceived') {
        final Object? args = call.arguments;
        if (args is Map<Object?, Object?>) {
          handler(args.cast<String, String>());
        }
      }
    });
  }
}
