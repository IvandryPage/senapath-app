package com.example.senapath

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterFragmentActivity() {
    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingExportBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.dartExecutor.binaryMessenger.let { messenger ->
            MethodChannel(messenger, FILE_EXPORT_CHANNEL).setMethodCallHandler { call, result ->
                if (call.method != "saveFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName")
                val mimeType = call.argument<String>("mimeType")
                if (bytes == null || fileName.isNullOrBlank() || mimeType.isNullOrBlank()) {
                    result.error("invalid_arguments", "File content and metadata are required.", null)
                    return@setMethodCallHandler
                }
                if (pendingExportResult != null) {
                    result.error("export_in_progress", "Another file export is already in progress.", null)
                    return@setMethodCallHandler
                }

                pendingExportResult = result
                pendingExportBytes = bytes
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mimeType
                    putExtra(Intent.EXTRA_TITLE, fileName)
                }
                try {
                    startActivityForResult(intent, FILE_EXPORT_REQUEST_CODE)
                } catch (error: Exception) {
                    clearPendingExport()
                    result.error("file_picker_unavailable", error.message, null)
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != FILE_EXPORT_REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pendingExportResult
        val bytes = pendingExportBytes
        clearPendingExport()
        if (result == null || bytes == null) return
        if (resultCode != Activity.RESULT_OK) {
            result.success(false)
            return
        }

        val uri: Uri? = data?.data
        if (uri == null) {
            result.error("missing_file_uri", "The selected file location is unavailable.", null)
            return
        }
        try {
            val output = contentResolver.openOutputStream(uri, "w")
                ?: throw IOException("Unable to open the selected file.")
            output.use { it.write(bytes) }
            result.success(true)
        } catch (error: Exception) {
            result.error("file_write_failed", error.message, null)
        }
    }

    private fun clearPendingExport() {
        pendingExportResult = null
        pendingExportBytes = null
    }

    companion object {
        private const val FILE_EXPORT_CHANNEL = "senapath/file_export"
        private const val FILE_EXPORT_REQUEST_CODE = 0x534e
    }
}