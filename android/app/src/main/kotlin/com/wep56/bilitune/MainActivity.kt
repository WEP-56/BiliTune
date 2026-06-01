package com.wep56.bilitune

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.wep56.bilitune/notifications"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPostNotifications" -> result.success(requestPostNotifications())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.wep56.bilitune/update"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallApk" -> result.success(canInstallApk())
                "openInstallSettings" -> {
                    openInstallSettings()
                    result.success(true)
                }
                "installApk" -> result.success(installApk(call.argument<String>("path")))
                else -> result.notImplemented()
            }
        }
    }

    private fun requestPostNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            return true
        }
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 3301)
        return false
    }

    private fun canInstallApk(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        return packageManager.canRequestPackageInstalls()
    }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName")
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun installApk(path: String?): Boolean {
        if (path.isNullOrBlank()) return false
        val file = File(path)
        if (!file.exists()) return false

        if (!canInstallApk()) {
            openInstallSettings()
            return false
        }

        val authority = "$packageName.fileprovider"
        val uri = FileProvider.getUriForFile(this, authority, file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
        return true
    }
}
