package com.android_package_installer

import android.annotation.TargetApi
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.os.Bundle
import io.flutter.plugin.common.PluginRegistry

internal class OnNewIntentListener(private var activity: Activity?) : PluginRegistry.NewIntentListener {
    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    override fun onNewIntent(intent: Intent): Boolean {
        if (intent.action == packageInstalledAction && intent.extras != null) {
            val extras: Bundle = intent.extras ?: return false
            when (val status = extras.getInt(PackageInstaller.EXTRA_STATUS)) {
                PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                    val confirmIntent = extras.get(Intent.EXTRA_INTENT) as? Intent
                    if (confirmIntent != null) {
                        confirmIntent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
                        activity?.startActivity(confirmIntent)
                        MethodCallHandler.resultSuccess(PackageInstaller.STATUS_PENDING_USER_ACTION)
                    } else {
                        MethodCallHandler.resultSuccess(installStatusUnknown)
                    }
                }

                else -> {
                    MethodCallHandler.resultSuccess(status)
                }
            }
        }
        return true
    }
}
