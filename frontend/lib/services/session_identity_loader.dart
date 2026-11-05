import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/token_validator.dart';

/// Validates the person independently of any saved branch preference.
/// Transport/service failures leave credentials intact and can be retried.
class SessionIdentityLoader {
  SessionIdentityLoader({
    required this.readAccessToken,
    required this.refreshAccessToken,
    required this.fetchUser,
    required this.signOut,
  });
  final Future<String?> Function() readAccessToken, refreshAccessToken;
  final Future<http.Response> Function(String token) fetchUser;
  final Future<void> Function() signOut;

  Future<Map<String, dynamic>?> load({bool allowRefresh = true}) async {
    var token = await readAccessToken();
    var refreshed = false;
    if (token == null ||
        token.isEmpty ||
        TokenValidator.isTokenExpired(token, buffer: Duration.zero)) {
      if (!allowRefresh) return null;
      token = await refreshAccessToken();
      refreshed = true;
    }
    if (token == null || token.isEmpty) return null;

    while (true) {
      final response = await fetchUser(token!);
      final data = jsonDecode(response.body) as Map;
      if (response.statusCode == 200) {
        final attributes = <String, dynamic>{
          for (final a in data['UserAttributes'] as List)
            a['Name'] as String: a['Value'],
        };
        final subject = attributes['sub'];
        if (subject is! String || subject.isEmpty) {
          throw const FormatException('Missing account identity');
        }
        return {
          ...attributes,
          'userId': subject,
          'sub': subject,
          'email': attributes['email'] ?? '',
        };
      }
      final code = '${data['__type']}'.split('#').last;
      if (code == 'UserNotFoundException') {
        await signOut();
        return null;
      }
      if (code == 'NotAuthorizedException') {
        if (allowRefresh && !refreshed) {
          // A failed network refresh throws; it must never trigger sign-out.
          token = await refreshAccessToken();
          refreshed = true;
          if (token != null && token.isNotEmpty) continue;
        }
        await signOut();
        return null;
      }
      throw StateError('Account verification temporarily unavailable');
    }
  }
}
