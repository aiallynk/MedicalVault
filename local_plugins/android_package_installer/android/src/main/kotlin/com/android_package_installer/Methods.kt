package com.android_package_installer

import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class MethodCallHandler(private val installer: Installer) : MethodChannel.MethodCallHandler {
    companion object {
        lateinit var callResult: MethodChannel.Result
        private var hasPendingResult: Boolean = false

        fun bindResult(result: MethodChannel.Result) {
            callResult = result
            hasPendingResult = true
        }

        fun resultSuccess(data: Any) {
            if (!hasPendingResult) return
            hasPendingResult = false
            callResult.success(data)
        }

        fun nothing() {
            if (!hasPendingResult) return
            hasPendingResult = false
            callResult.notImplemented()
        }

        /*
        fun resultError(s0: String, s1: String, o: Any) {
            callResult.error(s0, s1, o)
        }
        */
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        bindResult(result)
        when (call.method) {
            "installApk" -> {
                try {
                    val apkFilePath = call.arguments.toString()
                    installer.installPackage(apkFilePath)
                } catch (e: Exception) {
                    // Log the real cause (missing activity reference,
                    // SecurityException from a denied install-packages
                    // grant, IOException from a bad path, etc) so a native
                    // install failure is diagnosable via adb logcat instead
                    // of only ever surfacing as an opaque "Unknown
                    // installer status." on the Dart side.
                    Log.e("AndroidPackageInstaller", "installApk failed", e)
                    resultSuccess(installStatusUnknown)
                }
            }
            else -> {
                nothing()
            }
        }
    }
}
