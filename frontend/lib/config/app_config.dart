import 'merchant_auth_routes.dart';

class AppConfig {
  // Environment variables from dart-define
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'staging',
  );
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue:
        'https://ie7z8r4wc0.execute-api.us-east-1.amazonaws.com/staging',
  );
  static const String authMode = String.fromEnvironment(
    'AUTH_MODE',
    defaultValue: 'cognito',
  );
  // Phone-based pool: WhizzMerchants-phone-users-staging
  static const String cognitoUserPoolId = String.fromEnvironment(
    'COGNITO_USER_POOL_ID',
    defaultValue: 'us-east-1_gtCR3ndzT',
  );
  static const String appClientId = String.fromEnvironment(
    'APP_CLIENT_ID',
    defaultValue: '4qabvh11nmghmf9fmc6e6ludd2',
  );
  static const String cognitoRegion = String.fromEnvironment(
    'COGNITO_REGION',
    defaultValue: 'us-east-1',
  );
  static const String cognitoIdentityPoolId = String.fromEnvironment(
    'COGNITO_IDENTITY_POOL_ID',
    defaultValue: '',
  );
  static const String featureSet = String.fromEnvironment(
    'FEATURE_SET',
    defaultValue: 'enhanced',
  );

  // Backward compatibility - some services use baseUrl
  static String get baseUrl => apiUrl;

  // Central Notifications (shared push service)
  static String get pushNotificationsUrl {
    return const String.fromEnvironment(
      'PUSH_NOTIFICATIONS_URL',
      defaultValue:
          'https://x066k4dftk.execute-api.us-east-1.amazonaws.com/staging',
    );
  }

  // OrderService URL - Unified order cancellation service
  static String get orderServiceUrl {
    return const String.fromEnvironment(
      'ORDER_SERVICE_URL',
      // Staging repo fallback: OrderService API Gateway (staging)
      defaultValue:
          'https://mqwom78d3c.execute-api.us-east-1.amazonaws.com/staging',
    );
  }

  // WebSocket URL - Using shared WizzUser-WebSocket-dev infrastructure
  // FIXED: Use the correct WebSocket endpoint for order notifications
  static String get webSocketUrl {
    return const String.fromEnvironment(
      'WEBSOCKET_URL',
      defaultValue:
          'wss://igcrhwc84c.execute-api.us-east-1.amazonaws.com/staging',
    );
  }

  // Support Chat WebSocket URL (WizzCentral support)
  static String get supportChatWebSocketUrl {
    return const String.fromEnvironment(
      'SUPPORT_CHAT_WEBSOCKET_URL',
      defaultValue: environment == 'staging'
          ? 'wss://vzvnqu5jhl.execute-api.us-east-1.amazonaws.com/staging'
          : '',
    );
  }

  // Dedicated private support attachment route; never the order API.
  static String get supportAttachmentsApiUrl => const String.fromEnvironment(
        'SUPPORT_ATTACHMENTS_API_URL',
        defaultValue: environment == 'staging'
            ? 'https://5ytyphpnkc.execute-api.us-east-1.amazonaws.com/staging/support/attachments'
            : '',
      );

  static const accountDeletionProductionUrl =
      String.fromEnvironment('ACCOUNT_DELETION_PRODUCTION_URL');

  // WhizzMe (AI) API URL
  static String get whizzMeApiUrl {
    return const String.fromEnvironment('WHIZZME_API_URL', defaultValue: '');
  }

  static const _ownershipTransferEnabled =
      bool.fromEnvironment('MERCHANT_OWNERSHIP_TRANSFER_ENABLED');
  static bool get ownershipTransferEnabled =>
      isStaging && _ownershipTransferEnabled;

  static const _ownershipPreviewBranch =
      String.fromEnvironment('MERCHANT_OWNERSHIP_PREVIEW_BUSINESS_ID');
  static bool ownershipPreviewEnabled(String? businessId) =>
      isStaging && _ownershipPreviewBranch.isNotEmpty &&
      businessId == _ownershipPreviewBranch;

  // Development flags
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';

  // Authentication configuration flags
  static bool get isCognitoConfigured =>
      cognitoUserPoolId.isNotEmpty && appClientId.isNotEmpty;

  // Feature flags
  static bool get isEnhancedMode => featureSet == 'enhanced';

  static void validateOrThrow() {
    final env = environment.trim();
    if (isProduction) {
      for (final url in [apiUrl, orderServiceUrl, pushNotificationsUrl]) {
        MerchantAuthRoutes.validateProductionEndpoint(url);
      }
      MerchantAuthRoutes.validateProductionEndpoint(webSocketUrl, socket: true);
      // Optional integrations must obey the same environment boundary as orders.
      // Empty means unavailable; a staging URL must never receive production tokens.
      for (final url in [supportAttachmentsApiUrl, whizzMeApiUrl, accountDeletionProductionUrl]) {
        if (url.trim().isNotEmpty) {
          MerchantAuthRoutes.validateProductionEndpoint(url);
        }
      }
      if (supportChatWebSocketUrl.trim().isNotEmpty) {
        MerchantAuthRoutes.validateProductionEndpoint(
          supportChatWebSocketUrl,
          socket: true,
        );
      }
      if (cognitoUserPoolId != 'us-east-1_2sKZ4fGbZ' ||
          appClientId != '5l8ng11uudg146crop63926svq') {
        throw StateError('Production merchant identity is not configured');
      }
    }

    void requireNonEmpty(String key, String value) {
      if (value.trim().isEmpty) {
        throw StateError('Missing required configuration: $key');
      }
    }

    void forbidDevInUrl(String key, String value) {
      final v = value.trim();
      if (v.contains('/dev') || v.endsWith('/dev')) {
        throw StateError('Invalid $key for $env (contains /dev): $v');
      }
    }

    // Always require these URLs in staging repo builds.
    requireNonEmpty('API_URL', apiUrl);
    requireNonEmpty('ORDER_SERVICE_URL', orderServiceUrl);
    requireNonEmpty('WEBSOCKET_URL', webSocketUrl);
    requireNonEmpty('PUSH_NOTIFICATIONS_URL', pushNotificationsUrl);
    // Optional features: keep empty unless explicitly configured.

    if (env == 'staging' || env == 'production') {
      forbidDevInUrl('API_URL', apiUrl);
      forbidDevInUrl('ORDER_SERVICE_URL', orderServiceUrl);
      forbidDevInUrl('WEBSOCKET_URL', webSocketUrl);
      forbidDevInUrl('PUSH_NOTIFICATIONS_URL', pushNotificationsUrl);
      if (supportChatWebSocketUrl.trim().isNotEmpty) {
        forbidDevInUrl('SUPPORT_CHAT_WEBSOCKET_URL', supportChatWebSocketUrl);
      }
      if (whizzMeApiUrl.trim().isNotEmpty) {
        forbidDevInUrl('WHIZZME_API_URL', whizzMeApiUrl);
      }
    }
  }
}
