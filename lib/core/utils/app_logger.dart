import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Centralized logging utility for the application.
/// Uses dart:developer in debug mode for better DevTools integration.
class AppLogger {
  AppLogger._();

  static const String _tag = 'CommonPlaceBook';

  /// Log debug information (only in debug mode)
  static void debug(String message, {String? tag, Object? error}) {
    if (kDebugMode) {
      _log('DEBUG', message, tag: tag, error: error);
    }
  }

  /// Log informational messages
  static void info(String message, {String? tag}) {
    _log('INFO', message, tag: tag);
  }

  /// Log warning messages
  static void warning(String message, {String? tag, Object? error}) {
    _log('WARNING', message, tag: tag, error: error);
  }

  /// Log error messages
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log('ERROR', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void _log(
    String level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final fullTag = tag != null ? '$_tag:$tag' : _tag;
    final logMessage = '[$level] $message';

    if (kDebugMode) {
      developer.log(
        logMessage,
        name: fullTag,
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      // In release mode, you might want to send to a crash reporting service
      // For now, we just print errors
      if (level == 'ERROR' || level == 'WARNING') {
        debugPrint('$fullTag: $logMessage');
        if (error != null) {
          debugPrint('Error: $error');
        }
      }
    }
  }
}
