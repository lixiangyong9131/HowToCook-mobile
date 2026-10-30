package com.howtocook.how_to_cook

import android.app.PendingIntent
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.howtocook.how_to_cook/installer"
    private val tag = "HowToCookInstall"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("bad_args", "path required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(installApk(path))
                        } catch (e: Exception) {
                            Log.e(tag, "installApk failed", e)
                            result.error("install_failed", e.message, null)
                        }
                    }
                    "canInstallPackages" -> {
                        val ok =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                packageManager.canRequestPackageInstalls()
                            } else {
                                true
                            }
                        result.success(ok)
                    }
                    "openInstallPermissionSettings" -> {
                        openInstallPermissionSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    /**
     * Root-cause notes (v0.6.10/0.6.11 failures):
     * 1) Downloading to external-cache tripped open_filex MANAGE_EXTERNAL_STORAGE.
     * 2) Incomplete downloads can still start with PK\x03\x04 → install fails.
     * 3) FLAG_GRANT_READ_URI_PERMISSION alone is flaky on some OEMs without ClipData.
     * 4) PackageInstaller session is more reliable for in-app updates than ACTION_VIEW.
     *
     * Strategy: copy into cacheDir (always <cache-path>), require install permission,
     * try PackageInstaller session, fall back to ACTION_VIEW with ClipData grants.
     */
    private fun installApk(path: String): String {
        val src = File(path)
        if (!src.exists() || src.length() < 1024L * 1024L) {
            throw IllegalStateException(
                "file_not_found_or_too_small:${src.length()}",
            )
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (!packageManager.canRequestPackageInstalls()) {
                openInstallPermissionSettings()
                return "need_permission"
            }
        }

        // Always install from app cache — covered by filepaths <cache-path>.
        val destDir = File(cacheDir, "updates").apply { mkdirs() }
        val apk = File(destDir, "how_to_cook_update.apk")
        src.copyTo(apk, overwrite = true)
        Log.i(tag, "install from ${apk.absolutePath} size=${apk.length()}")

        return try {
            installViaSession(apk)
            "session_committed"
        } catch (e: Exception) {
            Log.w(tag, "session install failed, fallback VIEW", e)
            installViaViewIntent(apk)
            "launched"
        }
    }

    private fun installViaSession(apk: File): String {
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            params.setRequireUserAction(
                PackageInstaller.SessionParams.USER_ACTION_REQUIRED,
            )
        }
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("app.apk", 0, apk.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
            val action = "$packageName.INSTALL_COMPLETE"
            val callback = Intent(action).setPackage(packageName)
            val flags =
                PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        PendingIntent.FLAG_MUTABLE
                    } else {
                        0
                    }
            val pending = PendingIntent.getBroadcast(
                this,
                sessionId,
                callback,
                flags,
            )
            session.commit(pending.intentSender)
        }
        return "session_committed"
    }

    private fun installViaViewIntent(apk: File) {
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            // ClipData + grant flags: required on many OEMs for content:// APKs.
            clipData = ClipData.newRawUri("", uri)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }

        val matches = packageManager.queryIntentActivities(
            intent,
            PackageManager.MATCH_DEFAULT_ONLY,
        )
        Log.i(tag, "VIEW matches=${matches.size}")
        for (info in matches) {
            grantUriPermission(
                info.activityInfo.packageName,
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        }
        if (matches.isEmpty()) {
            // Last resort: INSTALL_PACKAGE action.
            intent.action = Intent.ACTION_INSTALL_PACKAGE
        }
        startActivity(intent)
    }

}
