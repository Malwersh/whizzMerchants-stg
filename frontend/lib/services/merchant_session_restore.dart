import '../utils/token_validator.dart';

/// Restore credentials through Cognito when the app's local copy is missing,
/// expired, or rejected. A temporary failure propagates so the UI can retry.
Future<Map<String, dynamic>?> restoreMerchantSession({
  required Future<String?> Function() readAccessToken,
  required Future<String?> Function({required bool forceRefresh})
      restoreAccessToken,
  required Future<Map<String, dynamic>?> Function(String token) verifyUser,
}) async {
  final cached = await readAccessToken();
  if (cached != null &&
      !TokenValidator.isTokenExpired(cached, buffer: Duration.zero)) {
    final user = await verifyUser(cached);
    if (user != null) return user;
  }

  final recovered = await restoreAccessToken(
    forceRefresh: cached != null && cached.isNotEmpty,
  );
  if (recovered == null ||
      TokenValidator.isTokenExpired(recovered, buffer: Duration.zero))
    return null;
  return verifyUser(recovered);
}
