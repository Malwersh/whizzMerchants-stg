package com.whizz.merchant

import android.app.Activity
import android.content.Intent
import android.provider.DocumentsContract
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var exportResult: MethodChannel.Result? = null
    private var exportBytes: ByteArray? = null
    private val exportRequestCode = 31465
    private val CHANNEL = "com.whizz.merchant/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SoundFiles.install(this, flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.whizz.merchants/statement-export").setMethodCallHandler { call, result ->
            if (call.method != "saveCsv") { result.notImplemented() }
            else if (exportResult != null) { result.error("EXPORT_BUSY", null, null) }
            else {
                val filename = call.argument<String>("filename") ?: ""
                val bytes = call.argument<ByteArray>("bytes")
                if (!Regex("^branch-(statement|sales-report)-\\d{4}-\\d{2}-\\d{2}-\\d{4}-\\d{2}-\\d{2}\\.csv$").matches(filename) || bytes == null || bytes.isEmpty() || bytes.size > 2 * 1024 * 1024) {
                    result.error("INVALID_EXPORT", null, null)
                } else {
                    exportResult = result
                    exportBytes = bytes
                    try {
                        val picker = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "text/csv"
                            putExtra(Intent.EXTRA_TITLE, filename)
                        }
                        startActivityForResult(picker, exportRequestCode)
                    } catch (_: Exception) {
                        exportResult = null
                        exportBytes?.fill(0); exportBytes = null
                        result.error("EXPORT_FAILED", "تعذر فتح حفظ الكشف", null)
                    }
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "keepScreenOn" -> {
                    val keepOn = call.argument<Boolean>("keepOn") ?: false
                    if (keepOn) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                "getBatteryOptimizationStatus" -> {
                    result.success(true)
                }
                "requestDisableBatteryOptimization" -> {
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != exportRequestCode) return
        val result = exportResult ?: return
        val bytes = exportBytes ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || uri.scheme != "content") {
            exportResult = null; exportBytes = null; bytes.fill(0)
            result.success(false)
            return
        }
        // The URI is granted by the system picker for this export only.
        // Do not retain access or request general storage permissions.
        Thread {
            var failure = false
            try {
                val output = contentResolver.openOutputStream(uri, "w") ?: throw java.io.IOException()
                output.use { it.write(bytes); it.flush() }
            } catch (_: Exception) {
                failure = true
                // Remove a newly created partial file when the provider supports it.
                try { DocumentsContract.deleteDocument(contentResolver, uri) } catch (_: Exception) { }
            } finally { bytes.fill(0) }
            runOnUiThread {
                if (exportResult === result) {
                    exportResult = null; exportBytes = null
                    if (failure) result.error("EXPORT_FAILED", "تعذر حفظ الكشف؛ تحقق من الملف في الوجهة المختارة", null)
                    else result.success(true)
                }
            }
        }.start()
    }

    override fun onDestroy() {
        exportResult?.error("EXPORT_INTERRUPTED", "توقفت عملية حفظ الكشف", null)
        exportResult = null
        // A write already handed to a provider may finish; never report success after teardown.
        exportBytes = null
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        when (intent.action) {
            Intent.ACTION_VIEW -> {
                val data = intent.data
                if (data != null && data.scheme == "hadhir" && data.host == "orders") {
                    val orderId = data.getQueryParameter("id")
                    // TODO: pass to Flutter via MethodChannel/EventChannel
                }
            }
        }
    }
}
