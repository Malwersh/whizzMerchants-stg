import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/utils/app_logger.dart';

/// Lightweight wrapper to log outbound HTTP requests & responses while masking sensitive data.
class LoggingHttpClient extends http.BaseClient {
  final http.Client _inner;
  final void Function(String) _logger;

  LoggingHttpClient({http.Client? inner, void Function(String)? logger})
      : _inner = inner ?? http.Client(),
        _logger = logger ?? ((msg) => AppLogger.api(msg));

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Mask Authorization token (show length + first/last 6 chars)
    final auth = request.headers['Authorization'];
    String masked = 'none';
    if (auth != null) {
      final token = auth.startsWith('Bearer ') ? auth.substring(7) : auth;
      if (token.length > 12) {
        masked =
            'Bearer ${token.substring(0, 6)}...${token.substring(token.length - 6)} (len=${token.length})';
      } else {
        masked = 'Bearer (len=${token.length})';
      }
    }

    _logger('➡️  ${request.method} ${request.url}  Auth:$masked');

    try {
      final resp = await _inner.send(request);
      _logger(
          '⬅️  ${request.method} ${request.url.path} -> ${resp.statusCode}');
      return resp;
    } catch (e) {
      _logger('❌ HTTP error ${request.method} ${request.url}: $e');
      rethrow;
    }
  }

  Future<http.Response> jsonRequest(String method, Uri uri,
      {Map<String, String>? headers, Object? body}) async {
    final rq = http.Request(method, uri);
    if (headers != null) rq.headers.addAll(headers);
    if (body != null) {
      if (body is String) {
        rq.body = body;
      } else {
        rq.headers['Content-Type'] =
            rq.headers['Content-Type'] ?? 'application/json';
        rq.body = jsonEncode(body);
      }
    }
    final streamed = await send(rq);
    return http.Response.fromStream(streamed);
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      jsonRequest('GET', url, headers: headers);

  @override
  Future<http.Response> post(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      jsonRequest('POST', url, headers: headers, body: body);

  @override
  Future<http.Response> put(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      jsonRequest('PUT', url, headers: headers, body: body);

  @override
  Future<http.Response> delete(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      jsonRequest('DELETE', url, headers: headers, body: body);
}
