/// Auth-specific exceptions for consistent error handling across the app

/// Thrown when a token has expired and refresh failed
class AuthTokenExpiredException implements Exception {
  final String message;
  final dynamic originalError;

  AuthTokenExpiredException([
    this.message = 'Authentication token has expired',
    this.originalError,
  ]);

  @override
  String toString() => 'AuthTokenExpiredException: $message';
}

/// Thrown when the user is not authorized (401/403)
class UnauthorizedException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  UnauthorizedException([
    this.message = 'Unauthorized access',
    this.statusCode,
    this.originalError,
  ]);

  @override
  String toString() =>
      'UnauthorizedException: $message (${statusCode ?? "unknown"})';
}

/// Thrown when a required token is missing
class MissingTokenException implements Exception {
  final String message;

  MissingTokenException([
    this.message = 'Required authentication token is missing',
  ]);

  @override
  String toString() => 'MissingTokenException: $message';
}

/// Thrown when a server-side 5xx error occurs
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  ServerException([
    this.message = 'Server error occurred',
    this.statusCode,
    this.originalError,
  ]);

  @override
  String toString() => 'ServerException: $message (${statusCode ?? "unknown"})';
}

/// Enum representing different auth failure types
enum AuthFailureType { tokenExpired, unauthorized, missingToken }

/// Wrapper for auth failure carrying type and optional exception
class AuthFailure {
  final AuthFailureType type;
  final Exception exception;

  const AuthFailure(this.type, this.exception);

  @override
  String toString() => 'AuthFailure(type: $type, exception: $exception)';
}
