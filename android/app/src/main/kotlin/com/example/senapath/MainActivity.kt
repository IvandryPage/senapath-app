package com.example.senapath

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterFragmentActivity() {
    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingExportBytes: ByteArray? = null
    private var ambientSensorManager: SensorManager? = null
    private var ambientSensorListener: SensorEventListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.dartExecutor.binaryMessenger.let { messenger ->
            EventChannel(messenger, AMBIENT_LIGHT_CHANNEL).setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                        val manager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
                        val sensor = manager?.getDefaultSensor(Sensor.TYPE_LIGHT)
                        if (manager == null || sensor == null) {
                            events.error(
                                "sensor_unavailable",
                                "This device does not provide an ambient light sensor.",
                                null,
                            )
                            return
                        }

                        val listener = object : SensorEventListener {
                            override fun onSensorChanged(event: SensorEvent) {
                                val lux = event.values.firstOrNull()
                                if (lux != null && lux.isFinite() && lux >= 0f) {
                                    events.success(lux.toInt())
                                }
                            }

                            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
                        }
                        ambientSensorManager = manager
                        ambientSensorListener = listener
                        if (!manager.registerListener(
                                listener,
                                sensor,
                                SensorManager.SENSOR_DELAY_NORMAL,
                            )
                        ) {
                            clearAmbientSensorListener()
                            events.error(
                                "sensor_unavailable",
                                "The ambient light sensor could not be started.",
                                null,
                            )
                        }
                    }

                    override fun onCancel(arguments: Any?) {
                        clearAmbientSensorListener()
                    }
                },
            )
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

    private fun clearAmbientSensorListener() {
        ambientSensorListener?.let { listener ->
            ambientSensorManager?.unregisterListener(listener)
        }
        ambientSensorListener = null
        ambientSensorManager = null
    }

    companion object {
        private const val FILE_EXPORT_CHANNEL = "senapath/file_export"
        private const val AMBIENT_LIGHT_CHANNEL = "senapath/ambient_light"
        private const val FILE_EXPORT_REQUEST_CODE = 0x534e
    }
}