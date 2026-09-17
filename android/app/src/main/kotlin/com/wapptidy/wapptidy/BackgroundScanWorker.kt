package com.wapptidy.wapptidy

/*
 * BackgroundScanWorker.kt
 *
 * Android WorkManager periodic worker (REQ-SET-04, P-02).
 *
 * Invariant P-02: Background scans DETECT ONLY. They NEVER delete, move, or modify files.
 */

import android.content.Context
import android.provider.MediaStore
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class BackgroundScanWorker(
    private val appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    companion object {
        const val WORK_TAG = "wapptidy_periodic_scan"
        private const val STORAGE_ALERT_THRESHOLD_BYTES = 5L * 1024 * 1024 * 1024 // 5 GB
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            // P-02: Detect only — query WhatsApp media volume
            var totalBytes = 0L
            var itemCount = 0

            val projection = arrayOf(
                MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.DATA
            )

            val uris = listOf(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            )

            for (uri in uris) {
                appContext.contentResolver.query(
                    uri,
                    projection,
                    null,
                    null,
                    null
                )?.use { cursor ->
                    val sizeCol = cursor.getColumnIndex(MediaStore.MediaColumns.SIZE)
                    val dataCol = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)

                    while (cursor.moveToNext()) {
                        val path = if (dataCol != -1) cursor.getString(dataCol) ?: "" else ""
                        if (path.contains("WhatsApp", ignoreCase = true)) {
                            val size = if (sizeCol != -1) cursor.getLong(sizeCol) else 0L
                            totalBytes += size
                            itemCount++
                        }
                    }
                }
            }

            // If storage exceeds threshold and notifications are enabled, post an alert
            if (totalBytes >= STORAGE_ALERT_THRESHOLD_BYTES) {
                val mb = totalBytes / (1024 * 1024)
                NotificationHelper.showNotification(
                    context = appContext,
                    id = 1001,
                    channelId = NotificationHelper.CHANNEL_STORAGE_ALERTS,
                    title = "WhatsApp Storage Alert",
                    body = "WhatsApp is consuming " + mb + " MB. Open WappTidy to review cleanup suggestions."
                )
            } else if (itemCount > 0 && !NotificationHelper.isQuietHours()) {
                NotificationHelper.showNotification(
                    context = appContext,
                    id = 1002,
                    channelId = NotificationHelper.CHANNEL_SCAN_REMINDERS,
                    title = "Maintenance Check Complete",
                    body = "Scanned " + itemCount + " WhatsApp media items. Tap to view cleanup opportunities."
                )
            }

            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
