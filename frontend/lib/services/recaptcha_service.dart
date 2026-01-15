import 'dart:async';
import 'package:flutter/foundation.dart';

// Conditional import for web-only JS functionality
@pragma('dart2js:tryInline')
class _Grecaptcha {
  static void ready(void Function() callback) {
    if (kIsWeb) {
      // Web implementation would go here
      callback();
    } else {
      // Mobile stub - just call the callback
      callback();
    }
  }

  static Future<String> execute(String siteKey, Action action) async {
    if (kIsWeb) {
      // Web implementation would return actual reCAPTCHA token
      return 'web-token';
    } else {
      // Mobile stub - return empty token
      return 'mobile-stub-token';
    }
  }
}

class Action {
  final String action;
  Action({required this.action});
}

class RecaptchaService {
  static const String _siteKey = '6Lfn1ukrAAAAAKpB6i10w_AC_3OwnddEjvmcEiP8';

  static Future<String?> getToken(String action) async {
    if (kIsWeb) {
      final completer = Completer<String?>();
      _Grecaptcha.ready(() async {
        try {
          final token =
              await _Grecaptcha.execute(_siteKey, Action(action: action));
          completer.complete(token);
        } catch (error) {
          completer.complete(null);
        }
      });
      return completer.future;
    }
    // For mobile platforms, return a stub token or null
    return 'mobile-platform-token';
  }
}
