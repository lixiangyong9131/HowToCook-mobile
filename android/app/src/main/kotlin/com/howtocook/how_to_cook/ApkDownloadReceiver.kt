package com.howtocook.how_to_cook

import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.io.File

/**
 * When [DownloadManager] finishes an APK update, persist cache + notify user to install.
 * Works even if the Flutter process was killed while downloading in the background.
 */
class ApkDownloadReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return
        val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
        if (id < 0) return
        val meta = ApkDownloadHelper.activeMeta(context)
        val tracked = (meta["downloadId"] as? Number)?.toLong() ?: -1L
        if (tracked != id) {
            Log.i(TAG, "ignore foreign download id=$id tracked=$tracked")
            return
        }
        val info = ApkDownloadHelper.query(context, id)
        val status = info["status"] as? String
        Log.i(TAG, "download complete id=$id status=$status info=$info")
        if (status != "successful") {
            showNotification(
                context,
                title = "更新下载失败",
                body = "请打开 App「我的 → 检查更新」重试",
                openInstall = false,
            )
            return
        }
        val path = (info["path"] as? String).orEmpty()
        val file = File(path)
        if (!file.exists() || file.length() < 5L * 1024L * 1024L) {
            showNotification(
                context,
                title = "更新下载异常",
                body = "安装包不完整，请重新下载",
                openInstall = false,
            )
            return
        }
        val tagName = (meta["tag"] as? String).orEmpty()
        val url = (meta["url"] as? String).orEmpty()
        ApkDownloadHelper.persistFlutterCache(
            context,
            path = file.absolutePath,
            versionTag = tagName,
            url = url,
            bytes = file.length(),
        )
        showNotification(
            context,
            title = "更新已下载完成",
            body = if (tagName.isNotEmpty()) "点此安装 $tagName" else "点此安装新版本",
            openInstall = true,
        )
    }

    private fun showNotification(
        context: Context,
        title: String,
        body: String,
        openInstall: Boolean,
    ) {
        ensureChannel(context)
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        if (openInstall) {
            launch.putExtra("open_update_install", true)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        val pi = PendingIntent.getActivity(context, 91002, launch, flags)
        val notif = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pi)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(NOTIF_ID, notif)
        } catch (e: SecurityException) {
            Log.w(TAG, "notify blocked", e)
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val ch = NotificationChannel(
            CHANNEL_ID,
            "应用更新",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "APK 后台下载完成通知"
        }
        mgr.createNotificationChannel(ch)
    }

    companion object {
        private const val TAG = "HowToCookDl"
        private const val CHANNEL_ID = "howto_cook_app_update"
        private const val NOTIF_ID = 91002
    }
}
