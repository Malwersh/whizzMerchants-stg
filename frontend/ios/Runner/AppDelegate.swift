import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var fcmMethodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register plugins (Firebase will be auto-configured by plugin)
    GeneratedPluginRegistrant.register(with: self)
    print("✅ Flutter plugins registered")
    
    // Set up Flutter Method Channel for FCM communication
    // Use a delayed setup to ensure FlutterViewController is ready
    DispatchQueue.main.async { [weak self] in
      guard let self = self,
        let controller = self.window?.rootViewController as? FlutterViewController
      else {
        print("⚠️ Could not get FlutterViewController in delayed setup")
        return
      }

      self.fcmMethodChannel = FlutterMethodChannel(
        name: "com.whizz.merchants/fcm",
        binaryMessenger: controller.binaryMessenger
      )
      print("✅ FlutterMethodChannel set up: com.whizz.merchants/fcm")

      // Force token fetch after channel setup
      print("🔥 Requesting FCM token immediately after channel setup...")
      Messaging.messaging().token { token, error in
        if let error = error {
          print("❌ Error fetching FCM token on startup: \(error)")
        } else if let token = token {
          self.fcmMethodChannel?.invokeMethod("onTokenRefresh", arguments: token)
        } else {
          print("⚠️ FCM Token is nil on startup")
        }
      }

      self.fcmMethodChannel?.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "getFCMToken":
          Messaging.messaging().token { token, error in
            if let error = error {
              print("❌ Error fetching FCM token: \(error)")
              result(
                FlutterError(code: "TOKEN_ERROR", message: error.localizedDescription, details: nil)
              )
            } else if let token = token {
              print("📱 FCM Token retrieved: \(token)")
              result(token)
            } else {
              result(FlutterError(code: "TOKEN_NULL", message: "Token is null", details: nil))
            }
          }
        case "requestNotificationPermissions":
          self?.requestNotificationPermissions(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // Register for remote notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, _ in
          print("🔔 Notification permission granted: \(granted)")
        }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    // Register for remote notifications
    application.registerForRemoteNotifications()

    // Set FCM messaging delegate
    // FlutterFire owns the messaging delegate and forwards token refresh events.

    // Explicitly request FCM token on startup (after APNs token is available)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      Messaging.messaging().token { token, error in
        if let error = error {
          print("❌ Error fetching FCM token on startup: \(error)")
        } else if let token = token {
          print("✅ FCM Token fetched on startup: \(token)")
        } else {
          print("⚠️ FCM Token is nil on startup - APNs might not be registered yet")
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Request notification permissions
  private func requestNotificationPermissions(result: @escaping FlutterResult) {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .badge, .sound]
      ) { granted, error in
        if let error = error {
          result(
            FlutterError(
              code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil))
        } else {
          result(granted)
        }
      }
    } else {
      result(true)
    }
  }

  // Handle FCM token refresh
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    Messaging.messaging().apnsToken = deviceToken

    // After setting APNs token, try to get FCM token
    Messaging.messaging().token { token, error in
      if let error = error {
        print("❌ Error fetching FCM token after APNs registration: \(error)")
      } else if let token = token {
      }
    }
  }

  // Handle registration failure
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ Failed to register for remote notifications: \(error)")
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {

    // Send token to Flutter via method channel
    if let token = fcmToken {
      fcmMethodChannel?.invokeMethod("onTokenRefresh", arguments: token)
    }

    // Also post to NotificationCenter for backward compatibility
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate {
  // Handle foreground notifications
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions)
      -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("📬 Foreground notification: \(userInfo)")

    // Send to Flutter
    if let fcmChannel = fcmMethodChannel {
      fcmChannel.invokeMethod("onMessageReceived", arguments: userInfo)
    }

    // Show notification even when app is in foreground
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }

  // Handle notification tap
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("👆 Notification tapped: \(userInfo)")

    // Send to Flutter
    if let fcmChannel = fcmMethodChannel {
      fcmChannel.invokeMethod("onNotificationTapped", arguments: userInfo)
    }

    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
