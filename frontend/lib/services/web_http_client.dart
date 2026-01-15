import 'package:http/http.dart' as http;

/// A custom HTTP client for the application.
class AppHttpClient {
  // Add cache-busting parameters to bypass CloudFront cache
  static Uri _addCacheBusting(Uri originalUri) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomSuffix = (DateTime.now().microsecond % 9999).toString();
    final Map<String, String> queryParams = Map.from(originalUri.queryParameters);
    queryParams['_cb'] = timestamp;        // Cache buster
    queryParams['_v'] = '2.0.2';          // Version parameter
    queryParams['_t'] = timestamp;         // Additional timestamp
    queryParams['_r'] = randomSuffix;      // Random component
    queryParams['nocache'] = 'true';      // No cache flag
    queryParams['bypass'] = 'cf';         // CloudFront bypass hint
    
    return originalUri.replace(queryParameters: queryParams);
  }

  // Add cache-busting headers that CloudFront typically respects
  static Map<String, String> _addCacheBustingHeaders(Map<String, String> headers) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomId = (DateTime.now().microsecond % 99999).toString();
    return {
      ...headers,
      'Cache-Control': 'no-cache, no-store, must-revalidate, max-age=0',
      'Pragma': 'no-cache',
      'Expires': '0',
      'X-Requested-With': 'XMLHttpRequest',
      'X-Cache-Buster': timestamp,
      'X-Request-ID': 'flutter-$timestamp-$randomId',
      'X-CloudFront-Bypass': 'true',
      'X-Forwarded-For': '127.0.0.1',
      'If-None-Match': '*',
      'X-Custom-Header': randomId,
    };
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    // Add cache-busting parameters to bypass CloudFront cache
    final cacheBustedUrl = _addCacheBusting(url);
    
    final baseHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };

    // Add cache-busting headers that CloudFront typically respects
    final allHeaders = _addCacheBustingHeaders(baseHeaders);

    // Note: Authorization header is now passed directly from ApiService
    // without Bearer prefix for AWS API Gateway Cognito Authorizer

    try {
      final response = await http
          .post(
        cacheBustedUrl,
        headers: allHeaders,
        body: body,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout after 30 seconds');
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    // Add cache-busting parameters to bypass CloudFront cache
    final cacheBustedUrl = _addCacheBusting(url);
    
    final baseHeaders = {
      'Accept': 'application/json',
      ...?headers,
    };

    // Add cache-busting headers that CloudFront typically respects
    final allHeaders = _addCacheBustingHeaders(baseHeaders);

    // Note: Authorization header is now passed directly from ApiService
    // without Bearer prefix for AWS API Gateway Cognito Authorizer

    try {
      final response = await http
          .get(
        cacheBustedUrl,
        headers: allHeaders,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout after 30 seconds');
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    // Add cache-busting parameters to bypass CloudFront cache
    final cacheBustedUrl = _addCacheBusting(url);
    
    final baseHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };

    // Add cache-busting headers that CloudFront typically respects
    final allHeaders = _addCacheBustingHeaders(baseHeaders);

    // Note: Authorization header is now passed directly from ApiService
    // without Bearer prefix for AWS API Gateway Cognito Authorizer

    try {
      final response = await http
          .put(
        cacheBustedUrl,
        headers: allHeaders,
        body: body,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout after 30 seconds');
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    // Add cache-busting parameters to bypass CloudFront cache
    final cacheBustedUrl = _addCacheBusting(url);
    
    final baseHeaders = {
      'Accept': 'application/json',
      ...?headers,
    };

    // Add cache-busting headers that CloudFront typically respects
    final allHeaders = _addCacheBustingHeaders(baseHeaders);

    // Note: Authorization header is now passed directly from ApiService
    // without Bearer prefix for AWS API Gateway Cognito Authorizer

    try {
      final response = await http
          .delete(
        cacheBustedUrl,
        headers: allHeaders,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout after 30 seconds');
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }
}
