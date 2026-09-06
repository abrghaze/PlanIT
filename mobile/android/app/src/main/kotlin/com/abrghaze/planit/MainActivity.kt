package com.abrghaze.planit

import android.app.Activity
import android.content.Intent
import java.io.ByteArrayOutputStream
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private var pendingOpenResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.abrghaze.planit/privacy_files",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveFile" -> startSave(call.arguments as? Map<*, *>, result)
                "openFile" -> startOpen(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun startSave(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (pendingSaveResult != null || pendingOpenResult != null) {
            result.error("FILE_ACTION_IN_PROGRESS", "Another file action is already open.", null)
            return
        }
        val filename = arguments?.get("filename") as? String
        val bytes = arguments?.get("bytes") as? ByteArray
        val mimeType = arguments?.get("mimeType") as? String ?: "application/octet-stream"
        if (filename.isNullOrBlank() || bytes == null) {
            result.error("INVALID_EXPORT", "The export file is invalid.", null)
            return
        }
        pendingSaveResult = result
        pendingBytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, filename)
        }
        startActivityForResult(intent, SAVE_FILE_REQUEST)
    }

    private fun startOpen(result: MethodChannel.Result) {
        if (pendingSaveResult != null || pendingOpenResult != null) {
            result.error("FILE_ACTION_IN_PROGRESS", "Another file action is already open.", null)
            return
        }
        pendingOpenResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
        }
        startActivityForResult(intent, OPEN_FILE_REQUEST)
    }

    @Deprecated("Deprecated in Android, retained for FlutterActivity compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OPEN_FILE_REQUEST) {
            finishOpen(resultCode, data)
            return
        }
        if (requestCode != SAVE_FILE_REQUEST) return
        val result = pendingSaveResult
        val bytes = pendingBytes
        pendingSaveResult = null
        pendingBytes = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(null)
            return
        }
        val uri = data.data!!
        try {
            contentResolver.openOutputStream(uri, "w")?.use { stream ->
                stream.write(bytes ?: ByteArray(0))
                stream.flush()
            } ?: throw IllegalStateException("The selected file could not be opened.")
            result?.success(uri.toString())
        } catch (error: Exception) {
            result?.error("SAVE_FAILED", "PlanIT could not write the selected file.", null)
        }
    }

    private fun finishOpen(resultCode: Int, data: Intent?) {
        val result = pendingOpenResult
        pendingOpenResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(null)
            return
        }
        try {
            val stream = contentResolver.openInputStream(data.data!!)
                ?: throw IllegalStateException("The selected file could not be opened.")
            val output = ByteArrayOutputStream()
            stream.use { input ->
                val buffer = ByteArray(8192)
                var total = 0
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    total += read
                    if (total > MAX_RESTORE_BYTES) {
                        throw IllegalArgumentException("The selected backup is too large.")
                    }
                    output.write(buffer, 0, read)
                }
            }
            result?.success(output.toByteArray())
        } catch (error: Exception) {
            result?.error("OPEN_FAILED", "PlanIT could not read the selected backup.", null)
        }
    }

    companion object {
        private const val SAVE_FILE_REQUEST = 4817
        private const val OPEN_FILE_REQUEST = 4818
        private const val MAX_RESTORE_BYTES = 20 * 1024 * 1024
    }
}
