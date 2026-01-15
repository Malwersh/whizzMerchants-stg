package com.whizz.merchant

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Firebase Cloud Messaging Service for Hadhir Business App
 * Handles push notifications for orders, promotions, and system alerts
 */
class FCMService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "FCMService"
        private const val CHANNEL_ID = "hadhir_business_notifications"
        private const val CHANNEL_NAME = "Business Notifications"
        private const val CHANNEL_DESCRIPTION = "Notifications for orders, promotions, and alerts"
    }

    /**
     * Called when a new FCM token is generated
     * This token uniquely identifies this device for push notifications
     */
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "New FCM Token: $token")
        
        // TODO: Send token to Flutter layer to store in backend
        // You can use a MethodChannel to communicate with Flutter
        sendTokenToFlutter(token)
    }

    /**
     * Called when a message is received from FCM
     * Handles both notification messages and data messages
     */
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        
        Log.d(TAG, "Message received from: ${message.from}")
        
        // Check if message contains a notification payload
        message.notification?.let {
            Log.d(TAG, "Notification title: ${it.title}")
            Log.d(TAG, "Notification body: ${it.body}")
            
            // Display notification
            sendNotification(
                title = it.title ?: "Hadhir Business",
                body = it.body ?: "",
                data = message.data
            )
        }
        
        // Check if message contains a data payload
        if (message.data.isNotEmpty()) {
            Log.d(TAG, "Message data payload: ${message.data}")
            
            // Handle data payload
            handleDataPayload(message.data)
        }
    }

    /**
     * Creates and displays a notification
     */
    private fun sendNotification(title: String, body: String, data: Map<String, String>) {
        // Create notification channel (required for Android O+)
        createNotificationChannel()
        
        // Create intent for when notification is tapped
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            
            // Add data to intent for deep linking
            data.forEach { (key, value) ->
                putExtra(key, value)
            }
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 
            0, 
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        // Get default notification sound
        val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        
        // Build notification
        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setSound(defaultSoundUri)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
        
        // Show notification
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(System.currentTimeMillis().toInt(), notificationBuilder.build())
    }

    /**
     * Creates notification channel for Android O and above
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESCRIPTION
                enableLights(true)
                enableVibration(true)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Handles data-only push notifications
     */
    private fun handleDataPayload(data: Map<String, String>) {
        // Parse notification type
        val notificationType = data["type"]
        
        when (notificationType) {
            "new_order" -> {
                // Handle new order notification
                Log.d(TAG, "New order notification received")
                sendNotification(
                    title = "New Order!",
                    body = data["message"] ?: "You have a new order",
                    data = data
                )
            }
            "order_update" -> {
                // Handle order status update
                Log.d(TAG, "Order update notification received")
                sendNotification(
                    title = "Order Update",
                    body = data["message"] ?: "Order status changed",
                    data = data
                )
            }
            "promotion" -> {
                // Handle promotional notification
                Log.d(TAG, "Promotion notification received")
                sendNotification(
                    title = data["title"] ?: "Special Promotion",
                    body = data["message"] ?: "Check out our latest promotion",
                    data = data
                )
            }
            "system_alert" -> {
                // Handle system alert
                Log.d(TAG, "System alert received")
                sendNotification(
                    title = "System Alert",
                    body = data["message"] ?: "Important system message",
                    data = data
                )
            }
            else -> {
                // Handle generic notification
                Log.d(TAG, "Generic notification received")
                sendNotification(
                    title = data["title"] ?: "Hadhir Business",
                    body = data["message"] ?: "You have a new notification",
                    data = data
                )
            }
        }
    }

    /**
     * Sends FCM token to Flutter layer
     * TODO: Implement MethodChannel communication
     */
    private fun sendTokenToFlutter(token: String) {
        // Store token in SharedPreferences as a fallback
        val prefs = getSharedPreferences("fcm_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("fcm_token", token).apply()
        
        Log.d(TAG, "FCM Token stored: $token")
        
        // TODO: Send token to Flutter using MethodChannel
        // This will be implemented when Flutter integration is complete
    }
}
