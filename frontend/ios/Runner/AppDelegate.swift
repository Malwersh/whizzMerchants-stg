import UIKit
import Flutter
import GoogleMaps
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  private var fcmMethodChannel: FlutterMethodChannel?
  private var statementExportChannel: FlutterMethodChannel?
  private var statementExportResult: FlutterResult?
  private var statementExportDirectory: URL?


  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Read the existing bundled configuration without embedding keys in source.
    let mapsEnvURLs = [
      Bundle.main.bundleURL.appendingPathComponent("Frameworks/App.framework/flutter_assets/.env"),
      Bundle.main.bundleURL.appendingPathComponent("flutter_assets/.env")
    ]
    for url in mapsEnvURLs {
      if let contents = try? String(contentsOf: url, encoding: .utf8),
         let line = contents.components(separatedBy: .newlines).first(where: { $0.hasPrefix("GOOGLE_MAPS_API_KEY=") }) {
        let key = String(line.dropFirst("GOOGLE_MAPS_API_KEY=".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { GMSServices.provideAPIKey(key) }
        break
      }
    }
    // Register plugins (Firebase will be auto-configured by plugin)
    GeneratedPluginRegistrant.register(with: self)
    if let soundRegistrar = self.registrar(forPlugin: "NotificationSoundFiles") { NotificationSoundFiles.register(with: soundRegistrar) }
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

      self.configureStatementExport(controller)
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
  
  private var statementExportsRoot: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MerchantStatementExports", isDirectory: true)
  }

  private func configureStatementExport(_ controller: FlutterViewController) {
    // Remove remnants from a previous process before opening any new export.
    try? FileManager.default.removeItem(at: statementExportsRoot)
    statementExportChannel = FlutterMethodChannel(
      name: "com.whizz.merchants/statement-export", binaryMessenger: controller.binaryMessenger)
    statementExportChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "saveCsv" else { result(FlutterMethodNotImplemented); return }
      guard let self = self else { result(FlutterError(code: "EXPORT_UNAVAILABLE", message: nil, details: nil)); return }
      guard self.statementExportResult == nil else { result(FlutterError(code: "EXPORT_BUSY", message: nil, details: nil)); return }
      guard UIApplication.shared.applicationState == .active,
        controller.presentedViewController == nil,
        let args = call.arguments as? [String: Any],
        let filename = args["filename"] as? String,
        filename.rangeOfCharacter(from: .newlines) == nil,
        filename.range(of: #"^branch-(statement|sales-report)-\d{4}-\d{2}-\d{2}-\d{4}-\d{2}-\d{2}\.csv$"#, options: .regularExpression) != nil,
        let typedBytes = args["bytes"] as? FlutterStandardTypedData,
        case let bytes = typedBytes.data,
        !bytes.isEmpty, bytes.count <= 2 * 1024 * 1024
      else { result(FlutterError(code: "INVALID_EXPORT", message: nil, details: nil)); return }
      let directory = self.statementExportsRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
          attributes: [.protectionKey: FileProtectionType.complete])
        var privateDirectory = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try privateDirectory.setResourceValues(values)
        let file = directory.appendingPathComponent(filename)
        try bytes.write(to: file, options: [.atomic, .completeFileProtection])
        let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
        picker.delegate = self
        self.statementExportDirectory = directory
        self.statementExportResult = result
        controller.present(picker, animated: true)
        picker.presentationController?.delegate = self
      } catch {
        try? FileManager.default.removeItem(at: directory)
        result(FlutterError(code: "EXPORT_FAILED", message: "تعذر حفظ الكشف", details: nil))
      }
    }
  }

  private func finishStatementExport(_ saved: Bool) {
    let completion = statementExportResult
    statementExportResult = nil
    if let directory = statementExportDirectory { try? FileManager.default.removeItem(at: directory) }
    statementExportDirectory = nil
    completion?(saved)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finishStatementExport(!urls.isEmpty)
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finishStatementExport(false) }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    if presentationController.presentedViewController is UIDocumentPickerViewController { finishStatementExport(false) }
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
    // FlutterFire forwards to this original delegate when one exists.
    // Enforce silent foreground presentation here, not just in Dart settings.
    super.userNotificationCenter(center, willPresent: notification) { options in
      let foregroundOptions = options.subtracting(.sound)
      NSLog("Merchant foreground presentation: systemSound=false")
      completionHandler(foregroundOptions)
    }
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

final class NotificationSoundFiles: NSObject, FlutterPlugin {
 static func register(with registrar: FlutterPluginRegistrar) {
  let channel=FlutterMethodChannel(name:"wizz/notification-sound-files",binaryMessenger:registrar.messenger())
  registrar.addMethodCallDelegate(NotificationSoundFiles(),channel:channel)
 }
 func handle(_ call: FlutterMethodCall,result: @escaping FlutterResult) {
  guard call.method == "install" else { result(FlutterMethodNotImplemented);return }
  guard let args=call.arguments as? [String:Any],let name=args["file"] as? String,name.range(of:"^custom_[a-f0-9]{64}\\.wav$",options:.regularExpression) != nil,let value=args["bytes"] as? FlutterStandardTypedData,value.data.count>=44,value.data.count<=256000 else {result(FlutterError(code:"INVALID_SOUND",message:nil,details:nil));return}
  do {
   let dir=FileManager.default.urls(for:.libraryDirectory,in:.userDomainMask)[0].appendingPathComponent("Sounds",isDirectory:true)
   try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
   let file=dir.appendingPathComponent(name)
   if !FileManager.default.fileExists(atPath:file.path){try value.data.write(to:file,options:.atomic)}
   result(["path":file.path,"uri":file.absoluteString])
  } catch {result(FlutterError(code:"SOUND_INSTALL_FAILED",message:nil,details:nil))}
 }
}
