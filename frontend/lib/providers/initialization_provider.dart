import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../core/utils/app_logger.dart';
import '../services/notification_helper.dart';
import '../services/push_notifications_service.dart';

/// Provider to handle the asynchronous initialization of local notifications.
final notificationInitializationProvider = FutureProvider<void>((ref) async {
  try {
    // Initialize local notifications only
    await NotificationHelper.initialize();
    AppLogger.success('📱 Local notifications initialized successfully');

    // Initialize Firebase Cloud Messaging (push notifications)
    try {
      await PushNotificationsService.instance.initialize();
      AppLogger.success('✅ Push notifications (FCM) initialized');
    } catch (e) {
      AppLogger.warning('⚠️ Push notifications init failed (non-critical): $e');
      // Continue even if FCM fails (may be missing Firebase config files)
    }

  } catch (e) {
    AppLogger.warning('Notification initialization failed: $e');

    AppLogger.info('📱 App will continue without notifications');

  }
});

/// Provider to handle the asynchronous configuration of Amplify.
final amplifyConfigurationProvider = FutureProvider<void>((ref) async {
  // Wait for notifications to initialize first
  await ref.watch(notificationInitializationProvider.future);

  // If Amplify is already configured, don't re-configure.
  if (Amplify.isConfigured) {
    return;
  }

  try {
    await Amplify.addPlugins([AmplifyAuthCognito(), AmplifyAPI()]);

    final amplifyconfig = '''{
      "UserAgent": "aws-amplify-cli/2.0",
      "Version": "1.0",
      "auth": {
        "plugins": {
          "awsCognitoAuthPlugin": {
            "UserAgent": "aws-amplify-cli/0.1.0",
            "Version": "0.1.0",
            "CognitoUserPool": {
              "Default": {
                "PoolId": "${AppConfig.cognitoUserPoolId}",
                "AppClientId": "${AppConfig.appClientId}",
                "Region": "${AppConfig.cognitoRegion}"
              }
            },
            "Auth": {
              "Default": {
                "authenticationFlowType": "CUSTOM_AUTH"
              }
            }
          }
        }
      },
      "api": {
        "plugins": {
          "awsAPIPlugin": {
            "haddir-api": {
              "endpointType": "REST",
              "endpoint": "${AppConfig.baseUrl}",
              "region": "${AppConfig.cognitoRegion}",
              "authorizationType": "AMAZON_COGNITO_USER_POOLS"
            }
          }
        }
      }
    }''';

    await Amplify.configure(amplifyconfig);
  } catch (e) {
    AppLogger.error('Amplify configuration failed: $e');

    // Rethrow to be caught by the UI layer and display an error screen
    throw Exception('Failed to configure Amplify: $e');
  }
});
