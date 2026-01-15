/// Advanced Session State Models
/// Complete session management with comprehensive state tracking

import 'package:flutter/foundation.dart';

/// Base session state
@immutable
abstract class SessionState {
  const SessionState();
}

/// Initial state - app just started
class SessionInitial extends SessionState {
  const SessionInitial();
}

/// Loading state - checking session
class SessionLoading extends SessionState {
  final String? message;
  const SessionLoading({this.message});
}

/// Active authenticated session
class SessionActive extends SessionState {
  final String businessId;
  final String businessName;
  final String email;
  final Map<String, dynamic> businessData;
  final DateTime? expiresAt;
  final DateTime lastActivity;
  
  const SessionActive({
    required this.businessId,
    required this.businessName,
    required this.email,
    required this.businessData,
    this.expiresAt,
    required this.lastActivity,
  });

  SessionActive copyWith({
    String? businessId,
    String? businessName,
    String? email,
    Map<String, dynamic>? businessData,
    DateTime? expiresAt,
    DateTime? lastActivity,
  }) {
    return SessionActive(
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      email: email ?? this.email,
      businessData: businessData ?? this.businessData,
      expiresAt: expiresAt ?? this.expiresAt,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }

  /// Check if session is about to expire (less than 5 minutes)
  bool get isAboutToExpire {
    if (expiresAt == null) return false;
    final now = DateTime.now();
    final difference = expiresAt!.difference(now);
    return difference.inMinutes < 5;
  }

  /// Check if session is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Time remaining until expiry
  Duration? get timeRemaining {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }

  @override
  String toString() {
    return 'SessionActive(businessId: $businessId, businessName: $businessName, expiresAt: $expiresAt)';
  }
}

/// Session expired - needs refresh or re-login
class SessionExpired extends SessionState {
  final String? reason;
  final bool canRefresh;
  
  const SessionExpired({
    this.reason,
    this.canRefresh = true,
  });

  @override
  String toString() {
    return 'SessionExpired(reason: $reason, canRefresh: $canRefresh)';
  }
}

/// Session refreshing - getting new tokens
class SessionRefreshing extends SessionState {
  final String businessId;
  
  const SessionRefreshing({required this.businessId});
}

/// Session error - something went wrong
class SessionError extends SessionState {
  final String message;
  final String? code;
  final bool requiresLogin;
  
  const SessionError({
    required this.message,
    this.code,
    this.requiresLogin = false,
  });

  @override
  String toString() {
    return 'SessionError(message: $message, code: $code, requiresLogin: $requiresLogin)';
  }
}

/// Session terminated - user logged out
class SessionTerminated extends SessionState {
  final String? reason;
  final bool wasForced; // true if logged out by system
  
  const SessionTerminated({
    this.reason,
    this.wasForced = false,
  });

  @override
  String toString() {
    return 'SessionTerminated(reason: $reason, wasForced: $wasForced)';
  }
}

/// Session extended - lifetime increased
class SessionExtended extends SessionState {
  final String businessId;
  final DateTime newExpiresAt;
  
  const SessionExtended({
    required this.businessId,
    required this.newExpiresAt,
  });
}
