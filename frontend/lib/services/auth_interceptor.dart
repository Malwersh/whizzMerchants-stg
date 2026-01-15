import 'package:http/http.dart' as http;
import '../core/exceptions/auth_exceptions.dart';
import 'token_refresh_service.dart';

/// Lightweight auth interceptor utility for making authenticated requests
/// Throws UnauthorizedException or AuthTokenExpiredException which UI can catch.
class AuthHttp {
  static Future<http.Response> get(String url) async {
    final token = await TokenRefreshService.getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw AuthTokenExpiredException('Missing auth token');
    }
    final resp = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    _check(resp);
    return resp;
  }

  static Future<http.Response> post(String url, {Object? body}) async {
    final token = await TokenRefreshService.getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw AuthTokenExpiredException('Missing auth token');
    }
    final resp = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );
    _check(resp);
    return resp;
  }

  static Future<http.Response> put(String url, {Object? body}) async {
    final token = await TokenRefreshService.getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw AuthTokenExpiredException('Missing auth token');
    }
    final resp = await http.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );
    _check(resp);
    return resp;
  }

  static Future<http.Response> delete(String url) async {
    final token = await TokenRefreshService.getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw AuthTokenExpiredException('Missing auth token');
    }
    final resp = await http.delete(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    _check(resp);
    return resp;
  }

  static void _check(http.Response resp) {
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw UnauthorizedException('Unauthorized (${resp.statusCode})');
    }
    if (resp.statusCode == 440 || resp.statusCode == 498) {
      throw AuthTokenExpiredException('Token expired (${resp.statusCode})');
    }
  }
}
