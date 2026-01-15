import 'package:flutter/foundation.dart';

/// Application Logger
///
/// Provides centralized logging that only outputs in debug mode.
/// In production builds, all logs are automatically disabled.
class AppLogger {
  AppLogger._();

  /// Log an informational message
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('ℹ️ $prefix$message');
    }
  }

  /// Log a warning message
  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('⚠️ $prefix$message');
    }
  }

  /// Log an error message
  static void error(String message,
      [String? tag, Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('❌ $prefix$message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }

  /// Log a success message
  static void success(String message, [String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('✅ $prefix$message');
    }
  }

  /// Log a debug message
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('🔍 $prefix$message');
    }
  }

  /// Log an API call
  static void api(String message, [String? endpoint]) {
    if (kDebugMode) {
      final prefix = endpoint != null ? '[$endpoint] ' : '';
      debugPrint('🌐 $prefix$message');
    }
  }
}
