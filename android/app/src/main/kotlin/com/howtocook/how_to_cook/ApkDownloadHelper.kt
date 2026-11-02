package com.howtocook.how_to_cook

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.util.Log
import java.io.File

/**
 * System [DownloadManager] so APK updates keep downloading after the app
 * goes to background or the process is killed.
 *
 * Verify: 我的 → 检查更新 → 开始下载 → 立刻切到桌面/其他 App，
 * 通知栏进度继续；完成后点「继续安装」或通知进入安装。
 */
object ApkDownloadHelper {
    private const val tag = "HowToCookDl"
    const val PREFS = "howto_cook_update_dl"
    const val KEY_ID = "download_id"
    const val KEY_TAG = "download_tag"
    const val KEY_URL = "download_url"
    const val KEY_PATH = "download_path"

    fun destinationFile(context: Context): File {
        val base = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: context.filesDir
        val dir = File(base, "updates").apply { mkdirs() }
        return File(dir, "how_to_cook_update.apk")
    }

    fun enqueue(context: Context, url: String, versionTag: String): Long {
        val dest = destinationFile(context)
        if (dest.exists()) {
            try {
                dest.delete()
            } catch (_: Exception) {
            }
        }
        val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        // Cancel any previous tracked download for this app.
        val oldId = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(KEY_ID, -1L)
        if (oldId > 0) {
            try {
                dm.remove(oldId)
            } catch (_: Exception) {
            }
        }

        // App-specific external files — no storage permission; survives background.
        val relPath = "updates/how_to_cook_update.apk"
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle("程序员做饭指南")
            .setDescription("正在下载更新 ${versionTag.ifBlank { "" }}".trim())
            .setMimeType("application/vnd.android.package-archive")
            .setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
            )
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
            .setDestinationInExternalFilesDir(
                context,
                Environment.DIRECTORY_DOWNLOADS,
                relPath,
            )

        val id = dm.enqueue(request)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_ID, id)
            .putString(KEY_TAG, versionTag)
            .putString(KEY_URL, url)
            .putString(KEY_PATH, dest.absolutePath)
            .apply()
        Log.i(tag, "enqueued id=$id dest=${dest.absolutePath}")
        return id
    }

    fun query(context: Context, downloadId: Long): Map<String, Any?> {
        val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val q = DownloadManager.Query().setFilterById(downloadId)
        dm.query(q).use { c ->
            if (c == null || !c.moveToFirst()) {
                return mapOf(
                    "status" to "missing",
                    "bytesDownloaded" to 0,
                    "totalSize" to -1,
                )
            }
            val status = c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            val reason = try {
                c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
            } catch (_: Exception) {
                0
            }
            val downloaded = c.getLong(
                c.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR),
            )
            val total = c.getLong(
                c.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
            )
            val localUri = try {
                c.getString(c.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
            } catch (_: Exception) {
                null
            }
            val statusName = when (status) {
                DownloadManager.STATUS_PENDING -> "pending"
                DownloadManager.STATUS_RUNNING -> "running"
                DownloadManager.STATUS_PAUSED -> "paused"
                DownloadManager.STATUS_SUCCESSFUL -> "successful"
                DownloadManager.STATUS_FAILED -> "failed"
                else -> "unknown_$status"
            }
            val path = localUriToPath(localUri)
                ?: context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .getString(KEY_PATH, null)
            return mapOf(
                "status" to statusName,
                "reason" to reason,
                "bytesDownloaded" to downloaded,
                "totalSize" to total,
                "localUri" to localUri,
                "path" to path,
            )
        }
    }

    fun activeMeta(context: Context): Map<String, Any?> {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val id = p.getLong(KEY_ID, -1L)
        return mapOf(
            "downloadId" to id,
            "tag" to (p.getString(KEY_TAG, "") ?: ""),
            "url" to (p.getString(KEY_URL, "") ?: ""),
            "path" to (p.getString(KEY_PATH, "") ?: ""),
        )
    }

    fun clearMeta(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    fun remove(context: Context, downloadId: Long) {
        val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        try {
            dm.remove(downloadId)
        } catch (_: Exception) {
        }
        clearMeta(context)
    }

    private fun localUriToPath(localUri: String?): String? {
        if (localUri.isNullOrBlank()) return null
        return try {
            val uri = Uri.parse(localUri)
            if (uri.scheme == "file") uri.path else null
        } catch (_: Exception) {
            null
        }
    }

    /** Persist into Flutter shared_preferences so Dart [UpdateService.cachedApk] sees it. */
    fun persistFlutterCache(
        context: Context,
        path: String,
        versionTag: String,
        url: String,
        bytes: Long,
    ) {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        prefs.edit()
            .putString("flutter.update_apk_path", path)
            .putString("flutter.update_apk_tag", versionTag)
            .putString("flutter.update_apk_url", url)
            .putLong("flutter.update_apk_bytes", bytes)
            // shared_preferences also stores ints as Long on Android.
            .apply()
        Log.i(tag, "flutter cache persisted path=$path bytes=$bytes tag=$versionTag")
    }
}
