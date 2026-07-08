package com.example.hello

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val fileOpenerChannel = "medical_vault/file_opener"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fileOpenerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openFileChooser" -> {
                        val path = call.argument<String>("path").orEmpty()
                        val mimeType = call.argument<String>("mimeType").orEmpty()
                        val title = call.argument<String>("title").orEmpty()
                        openFileChooser(path, mimeType, title, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openFileChooser(
        path: String,
        mimeType: String,
        title: String,
        result: MethodChannel.Result
    ) {
        try {
            val file = File(path)
            if (!file.exists() || file.length() <= 0L) {
                result.error("FILE_NOT_FOUND", "The file is not available yet.", null)
                return
            }

            val authority = "${applicationContext.packageName}.fileprovider"
            val uri = FileProvider.getUriForFile(this, authority, file)
            val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType.ifBlank { "*/*" })
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            packageManager.queryIntentActivities(viewIntent, 0).forEach { resolveInfo ->
                grantUriPermission(
                    resolveInfo.activityInfo.packageName,
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            }

            val chooserTitle = title.ifBlank { "Open file" }
            startActivity(Intent.createChooser(viewIntent, chooserTitle))
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.error("NO_VIEWER", "No compatible viewer was found.", null)
        } catch (error: Exception) {
            result.error("OPEN_FAILED", error.message ?: "Could not open file.", null)
        }
    }
}
