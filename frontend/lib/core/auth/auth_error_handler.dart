import '../utils/app_logger.dart';

/// Global Auth Error Handler - Following wizzuser approach
/// 
/// This handler prevents automatic logout on 401/403 errors.
/// Instead, it logs warnings and lets the user continue using the app.
/// 
/// Key principle from wizzuser: 
/// "لا نقوم بتسجيل خروج تلقائي" (No automatic logout)
class AuthErrorHandler {
  /// Handle 401/403 errors without throwing UnauthorizedException
  /// 
  /// Returns false if error should be handled normally (not auth error)
  /// Returns true if error was handled as auth error (logged only, no exception)
  static bool handleAuthError({
    required int statusCode,
    required String context,
    String? message,
  }) {
    // Check if it's an auth error
    if (statusCode != 401 && statusCode != 403) {
      return false; // Not an auth error, handle normally
    }

    // ⚠️ Following wizzuser: Log only, NO automatic logout
    AppLogger.warning(
      '[$context] Auth error $statusCode - user will need to re-login (wizzuser approach)',
    );
    
    if (message != null) {
      AppLogger.debug('[$context] Error message: $message');
    }

    // Return true to indicate error was handled (no exception thrown)
    return true;
  }

  /// Check if an exception is an auth-related error that should be handled
  static bool isAuthException(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden') ||
        errorString.contains('invalid or expired');
  }

  /// Wrap API calls to prevent UnauthorizedException from propagating
  /// 
  /// Example:
  /// ```dart
  /// return await AuthErrorHandler.wrapApiCall(
  ///   context: 'getUserBusinesses',
  ///   call: () => api.getUserBusinesses(),
  ///   onAuthError: () => <Map<String, dynamic>>[],
  /// );
  /// ```
  static Future<T> wrapApiCall<T>({
    required String context,
    required Future<T> Function() call,
    required T Function() onAuthError,
  }) async {
    try {
      return await call();
    } catch (e) {
      if (isAuthException(e)) {
        AppLogger.warning(
          '[$context] Auth exception caught - returning fallback (wizzuser approach)',
        );
        AppLogger.debug('[$context] Exception: $e');
        return onAuthError();
      }
      rethrow;
    }
  }

  /// Log auth warning without disrupting user experience
  static void logAuthWarning(String context, {String? details}) {
    AppLogger.warning(
      '⚠️ [$context] Authentication issue detected - user may need to re-login',
    );
    if (details != null) {
      AppLogger.debug('[$context] Details: $details');
    }
  }

  /// Check if user should be notified about token expiry
  /// (but still no automatic logout!)
  static bool shouldNotifyTokenExpiry(int statusCode, String? message) {
    if (statusCode == 401) {
      final msg = message?.toLowerCase() ?? '';
      return msg.contains('expired') || msg.contains('invalid');
    }
    return false;
  }
}
