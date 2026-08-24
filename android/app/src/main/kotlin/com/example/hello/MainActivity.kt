package com.example.hello

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity: FlutterActivity() {
    private val fileOpenerChannel = "medical_vault/file_opener"
    private val sosSmsChannel = "medical_vault/sos_sms"
    private val googleConfigChannel = "medical_vault/google_sign_in_config"
    private val smsTimeoutMs = 15000L

    // Blocks screenshots and screen recording of medical document/session
    // content, and blanks the OS app-switcher thumbnail as a side effect.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, sosSmsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canSendSms" -> result.success(canSendSms())
                    "sendEmergencySms" -> {
                        val recipient = call.argument<String>("recipient").orEmpty()
                        val message = call.argument<String>("message").orEmpty()
                        sendEmergencySms(recipient, message, result)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, googleConfigChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getGoogleSignInConfig" -> result.success(googleSignInConfig())
                    else -> result.notImplemented()
                }
            }
    }

    private fun googleSignInConfig(): Map<String, Any?> {
        val resourceId = resources.getIdentifier(
            "default_web_client_id",
            "string",
            packageName
        )
        val webClientId = if (resourceId != 0) {
            try {
                resources.getString(resourceId)
            } catch (_: Exception) {
                ""
            }
        } else {
            ""
        }

        return mapOf(
            "packageName" to packageName,
            "defaultWebClientIdConfigured" to webClientId.isNotBlank(),
            "defaultWebClientId" to webClientId
        )
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

    private fun canSendSms(): Boolean {
        val hasTelephony = packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
        val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        return hasTelephony && hasPermission
    }

    private fun sendEmergencySms(
        recipient: String,
        message: String,
        result: MethodChannel.Result
    ) {
        val cleanedRecipient = recipient.trim()
        if (cleanedRecipient.isEmpty()) {
            result.success(smsResult(false, cleanedRecipient, "INVALID_RECIPIENT", "Recipient phone number is required."))
            return
        }
        if (message.trim().isEmpty()) {
            result.success(smsResult(false, cleanedRecipient, "EMPTY_MESSAGE", "SMS message is required."))
            return
        }
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) {
            result.success(smsResult(false, cleanedRecipient, "NO_TELEPHONY", "This device cannot send SMS."))
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED
        ) {
            result.success(smsResult(false, cleanedRecipient, "SEND_SMS_PERMISSION_DENIED", "SMS permission is required."))
            return
        }

        try {
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            val parts = smsManager.divideMessage(message)
            val action = "${packageName}.SOS_SMS_SENT.${UUID.randomUUID()}"
            val remainingParts = intArrayOf(parts.size.coerceAtLeast(1))
            var completed = false
            var firstErrorCode: String? = null
            var firstErrorMessage: String? = null

            lateinit var receiver: BroadcastReceiver
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (completed) return
                    if (resultCode != Activity.RESULT_OK && firstErrorCode == null) {
                        firstErrorCode = smsErrorCode(resultCode)
                        firstErrorMessage = smsErrorMessage(resultCode)
                    }
                    remainingParts[0] -= 1
                    if (remainingParts[0] <= 0) {
                        completed = true
                        unregisterReceiverSafely(receiver)
                        result.success(
                            smsResult(
                                firstErrorCode == null,
                                cleanedRecipient,
                                firstErrorCode,
                                firstErrorMessage
                            )
                        )
                    }
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, IntentFilter(action), Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                registerReceiver(receiver, IntentFilter(action))
            }

            val sentIntents = parts.indices.map { index ->
                val intent = Intent(action).setPackage(packageName)
                PendingIntent.getBroadcast(
                    this,
                    (System.currentTimeMillis() % Int.MAX_VALUE).toInt() + index,
                    intent,
                    pendingIntentFlags()
                )
            }

            Handler(Looper.getMainLooper()).postDelayed({
                if (completed) return@postDelayed
                completed = true
                unregisterReceiverSafely(receiver)
                result.success(
                    smsResult(
                        false,
                        cleanedRecipient,
                        "SMS_SEND_TIMEOUT",
                        "Timed out waiting for SMS send status."
                    )
                )
            }, smsTimeoutMs)

            smsManager.sendMultipartTextMessage(
                cleanedRecipient,
                null,
                parts,
                ArrayList(sentIntents),
                null
            )
        } catch (error: Exception) {
            result.success(
                smsResult(
                    false,
                    cleanedRecipient,
                    "SMS_SEND_FAILED",
                    error.message ?: "Unable to send SMS."
                )
            )
        }
    }

    private fun pendingIntentFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    private fun unregisterReceiverSafely(receiver: BroadcastReceiver) {
        try {
            unregisterReceiver(receiver)
        } catch (_: Exception) {
        }
    }

    private fun smsResult(
        success: Boolean,
        recipient: String,
        errorCode: String?,
        errorMessage: String?
    ): Map<String, Any?> {
        return mapOf(
            "success" to success,
            "recipient" to recipient,
            "errorCode" to errorCode,
            "errorMessage" to errorMessage
        )
    }

    private fun smsErrorCode(resultCode: Int): String {
        return when (resultCode) {
            SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "GENERIC_FAILURE"
            SmsManager.RESULT_ERROR_NO_SERVICE -> "NO_SERVICE"
            SmsManager.RESULT_ERROR_NULL_PDU -> "NULL_PDU"
            SmsManager.RESULT_ERROR_RADIO_OFF -> "RADIO_OFF"
            else -> "SEND_RESULT_$resultCode"
        }
    }

    private fun smsErrorMessage(resultCode: Int): String {
        return when (resultCode) {
            SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "Generic SMS failure."
            SmsManager.RESULT_ERROR_NO_SERVICE -> "No cellular SMS service available."
            SmsManager.RESULT_ERROR_NULL_PDU -> "Invalid SMS payload."
            SmsManager.RESULT_ERROR_RADIO_OFF -> "Cellular radio is off."
            else -> "SMS failed with Android result code $resultCode."
        }
    }
}
