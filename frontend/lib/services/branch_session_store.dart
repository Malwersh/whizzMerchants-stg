import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_token_storage.dart';

class StoredBranchSession {
  final bool authenticated;
  final String? businessId;
  final Map<String, dynamic>? businessData;
  const StoredBranchSession(
      {required this.authenticated, this.businessId, this.businessData});
}

/// A branch selection is a preference of one signed-in person, never authority.
/// The API still checks ownership and current membership on every request.
class BranchSessionStore {
  Future<String?> _subject() async {
    final token = await SecureTokenStorage.getIdToken() ??
        await SecureTokenStorage.getAccessToken();
    if (token == null) return null;
    try {
      return JwtDecoder.decode(token)['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<StoredBranchSession> read() async {
    final prefs = await SharedPreferences.getInstance();
    final subject = await _subject();
    final authenticated = subject != null;
    final id = prefs.getString('business_id') ??
        await SecureTokenStorage.getBusinessId();
    Map<String, dynamic>? data;
    try {
      final raw = prefs.getString('business_data');
      if (raw != null) data = Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {/* Ignore malformed cache. */}
    final cachedSubject = prefs.getString('business_selection_subject');
    final legacyOwnerMatches = data?['ownerId'] == subject &&
        data?['cognitoUserId'] == subject &&
        subject != null;
    if (!authenticated ||
        id == null ||
        (cachedSubject != subject && !legacyOwnerMatches)) {
      return StoredBranchSession(authenticated: authenticated);
    }
    if (data != null && (data['businessId'] ?? data['id']) != id) data = null;
    return StoredBranchSession(
        authenticated: authenticated, businessId: id, businessData: data);
  }

  Future<void> save(String id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final subject = await _subject();
    // Writes are serialized by SessionNotifier so a later clear always wins.
    await prefs.setString('business_id', id);
    await prefs.remove('session_business_id');
    await prefs.setString('business_data', jsonEncode(data));
    if (subject != null) {
      await prefs.setString('business_selection_subject', subject);
    } else {
      await prefs.remove('business_selection_subject');
    }
    await SecureTokenStorage.setBusinessId(id);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'business_id',
      'session_business_id',
      'business_data',
      'business_selection_subject'
    ]) {
      await prefs.remove(key);
    }
    await SecureTokenStorage.clearBusinessId();
  }
}
