# Merchant push and audio — Staging

Fixed iOS AppDelegate callbacks to forward notification presentation, taps and APNs registration to FlutterFire. Removed the custom Firebase Messaging delegate assignment and token-value logging. Preserved the existing native method channel for compatibility.

Push registration now includes token, account and business scope in its cache, coalesces concurrent registration requests, and binds the device after successful order loading when the business session was initially unavailable. New pending orders discovered by list refresh trigger the same deduplicated audio path as push/WebSocket, without sounding historical orders on initial list loading.

Validation: iOS simulator build succeeded. The current merchant simulator device was confirmed bound to its restaurant. A targeted notification referencing an existing test order was sent to that device only through the deployed internal push service; FCM accepted it with successCount=1, failureCount=0. The user confirmed the notification appeared with sound while the app was backgrounded. No order state or balance was changed by the notification test.

A new-order end-to-end foreground test and WebSocket-only delivery still need explicit observation; background push delivery is confirmed on this simulator. The server uses APNs alert payload with default sound in the background; the application asset sound is used by the in-app new-order path.
