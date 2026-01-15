import 'dart:io';
import 'package:flutter/foundation.dart';

/// Platform detection utility for adaptive UI
///
/// Provides methods to detect the current platform and choose
/// appropriate UI components accordingly.
class PlatformDetector {
  PlatformDetector._();

  /// Returns true if running on iOS or macOS
  static bool get isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  /// Returns true if running on Android or Fuchsia
  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isFuchsia;
  }

  /// Returns true if running on web
  static bool get isWeb => kIsWeb;

  /// Returns true if running on desktop (Windows, Linux, macOS)
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  /// Returns true if running on mobile (iOS or Android)
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  /// Returns the platform name as a string
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isFuchsia) return 'Fuchsia';
    return 'Unknown';
  }

  /// Returns true if the platform uses Cupertino design language
  static bool get usesCupertino => isIOS;

  /// Returns true if the platform uses Material design language
  static bool get usesMaterial => isAndroid || isWeb;
}
