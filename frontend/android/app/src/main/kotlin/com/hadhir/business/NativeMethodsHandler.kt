package com.whizz.merchant

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class NativeMethodsHandler(private val context: Context) {
    companion object { private const val CHANNEL = "com.whizz.merchant/native" }

    fun configureMethodChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermissions" -> result.success(checkAllPermissions())
                "requestBatteryOptimization" -> { requestBatteryOptimizationExemption(); result.success(true) }
                "checkNotificationPermission" -> result.success(areNotificationsEnabled())
                "openNotificationSettings" -> { openNotificationSettings(); result.success(true) }
                "startOrderSync" -> { OrderSyncService.startService(context); result.success(true) }
                "stopOrderSync" -> { OrderSyncService.stopService(context); result.success(true) }
                "makePhoneCall" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    if (phoneNumber != null) { makePhoneCall(phoneNumber); result.success(true) }
                    else result.error("INVALID_ARGUMENT", "Phone number is required", null)
                }
                "shareOrderData" -> {
                    val orderData = call.argument<String>("orderData")
                    val orderId = call.argument<String>("orderId")
                    if (orderData != null && orderId != null) { shareOrderData(orderData, orderId); result.success(true) }
                    else result.error("INVALID_ARGUMENT", "Order data and ID are required", null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkAllPermissions(): Map<String, Boolean> {
        return mapOf(
            "camera" to hasPermission(android.Manifest.permission.CAMERA),
            "location" to hasPermission(android.Manifest.permission.ACCESS_FINE_LOCATION),
            "phone" to hasPermission(android.Manifest.permission.CALL_PHONE),
            "notifications" to areNotificationsEnabled(),
            "storage" to hasStoragePermission()
        )
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) == 
               PackageManager.PERMISSION_GRANTED
    }

    private fun hasStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            hasPermission(android.Manifest.permission.READ_MEDIA_IMAGES)
        } else {
            hasPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE)
        }
    }

    private fun areNotificationsEnabled(): Boolean {
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(context.packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
            }
        }
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
            }
        }
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }

    private fun makePhoneCall(phoneNumber: String) {
        val intent = Intent(Intent.ACTION_CALL).apply {
            data = Uri.parse("tel:$phoneNumber")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        if (hasPermission(android.Manifest.permission.CALL_PHONE)) {
            context.startActivity(intent)
        }
    }

    private fun shareOrderData(orderData: String, orderId: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, "Order #$orderId Details")
            putExtra(Intent.EXTRA_TEXT, orderData)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val chooser = Intent.createChooser(intent, "Share Order Details")
        chooser.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(chooser)
    }
}
