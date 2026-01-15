package com.whizz.merchant

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {
                // Restart the order sync service after boot/update
                if (isServiceNeeded(context)) {
                    OrderSyncService.startService(context)
                }
            }
        }
    }
    
    private fun isServiceNeeded(context: Context): Boolean {
        // Check if user has enabled real-time order notifications
        val prefs = context.getSharedPreferences("hadhir_business_prefs", Context.MODE_PRIVATE)
        return prefs.getBoolean("enable_background_sync", true)
    }
}
