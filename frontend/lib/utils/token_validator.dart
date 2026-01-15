import 'package:jwt_decode/jwt_decode.dart';
import '../core/utils/app_logger.dart';

/// Helper for decoding JWTs and checking expiry/remaining time.
class TokenValidator {
  /// Returns expiry as DateTime if the token contains an `exp` claim.
  static DateTime? getExpiryDate(String token) {
    try {
      final payload = Jwt.parseJwt(token);
      final exp = payload['exp'];
      if (exp is int || exp is double) {
        final seconds = exp is int ? exp : (exp as double).toInt();
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {
      // Ignore parse errors – handled by caller.
    }
    return null;
  }

  /// Whether the token is expired, with an optional safety buffer (default 5m).
  static bool isTokenExpired(
    String token, {
    Duration buffer = const Duration(minutes: 5),
  }) {
    final expiry = getExpiryDate(token);
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry.subtract(buffer));
  }

  /// Human-friendly remaining time until expiry (or null if unknown).
  static Duration? getTimeUntilExpiry(String token) {
    final expiry = getExpiryDate(token);
    if (expiry == null) return null;
    return expiry.difference(DateTime.now());
  }

  /// Logs token info to help with debugging expiry-related issues.
  static void logTokenInfo(String token, {String label = 'Token'}) {
    final expiry = getExpiryDate(token);
    final remaining = expiry == null ? null : expiry.difference(DateTime.now());
    AppLogger.info(
      '[TokenValidator] $label exp=${expiry?.toIso8601String() ?? "unknown"} '
      'remaining=${remaining?.inMinutes ?? "n/a"}m',
    );
  }
}
