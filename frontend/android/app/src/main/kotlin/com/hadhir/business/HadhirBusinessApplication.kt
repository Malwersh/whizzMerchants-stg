package com.whizz.merchant

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationManagerCompat

class HadhirBusinessApplication : Application() {
    
    companion object {
        // Notification channels
        const val CHANNEL_ORDERS = "orders_channel"
        const val CHANNEL_URGENT = "urgent_orders_channel"
        const val CHANNEL_UPDATES = "updates_channel"
        const val CHANNEL_SYNC = "sync_channel"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Orders channel - High importance for new orders
            val ordersChannel = NotificationChannel(
                CHANNEL_ORDERS,
                "New Orders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for new incoming orders"
                enableLights(true)
                enableVibration(true)
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setShowBadge(true)
            }
            
            // Urgent orders channel - Max importance for urgent orders
            val urgentChannel = NotificationChannel(
                CHANNEL_URGENT,
                "Urgent Orders",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "High priority notifications for urgent orders"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setShowBadge(true)
                canBypassDnd()
            }
            
            // Updates channel - Default importance for general updates
            val updatesChannel = NotificationChannel(
                CHANNEL_UPDATES,
                "App Updates",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "General app updates and information"
                enableLights(false)
                enableVibration(false)
                setShowBadge(false)
            }
            
            // Sync channel - Low importance for background sync
            val syncChannel = NotificationChannel(
                CHANNEL_SYNC,
                "Background Sync",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background synchronization status"
                enableLights(false)
                enableVibration(false)
                setShowBadge(false)
                setSound(null, null)
            }
            
            // Create all channels
            notificationManager.createNotificationChannels(listOf(
                ordersChannel,
                urgentChannel,
                updatesChannel,
                syncChannel
            ))
        }
    }
}
