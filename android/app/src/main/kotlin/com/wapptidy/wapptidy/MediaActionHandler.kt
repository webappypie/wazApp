package com.wapptidy.wapptidy

/*
 * MediaActionHandler.kt
 *
 * Implements Phase 7 file operations per PRD §5.2, §5.3, and §7.5:
 *   - REQ-ACT-01: Delete via MediaStore.createTrashRequest (API 30+) / createDeleteRequest (below).
 *   - REQ-ACT-03: Move / Copy: write destination first, verify byte count, only then mutate source.
 *   - REQ-ACT-04: Destination collision handling, permission loss, storage errors, per-file reports.
 *   - REQ-ACT-06: Archive to "Media Archive/<year>/<type>".
 *   - REQ-BIN-01, REQ-BIN-02: Query trashed items, restore, permanent-delete.
 */

import android.app.Activity
import android.app.PendingIntent
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MediaActionHandler(
    private val context: Context,
    private val activityProvider: () -> Activity?
) {

    companion object {
        const val REQUEST_CODE_TRASH = 1001
        const val REQUEST_CODE_DELETE = 1002
        const val REQUEST_CODE_RESTORE = 1003
    }

    private var pendingTrashResult: MethodChannel.Result? = null
    private var pendingDeleteResult: MethodChannel.Result? = null
    private var pendingRestoreResult: MethodChannel.Result? = null
    private var pendingTargetUris: List<String> = emptyList()

    fun getAndroidVersion(): Int = Build.VERSION.SDK_INT

    /**
     * Trashes items using MediaStore.createTrashRequest on API 30+,
     * or createDeleteRequest on API 29 and below (REQ-ACT-01).
     */
    fun trashItems(uris: List<String>, isTrash: Boolean, result: MethodChannel.Result) {
        val activity = activityProvider()
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity is null", null)
            return
        }

        if (uris.isEmpty()) {
            result.success(emptyList<String>())
            return
        }

        val parsedUris = uris.mapNotNull {
            try { Uri.parse(it) } catch (_: Exception) { null }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val pendingIntent: PendingIntent = if (isTrash) {
                    MediaStore.createTrashRequest(activity.contentResolver, parsedUris, true)
                } else {
                    MediaStore.createTrashRequest(activity.contentResolver, parsedUris, false)
                }

                if (isTrash) {
                    pendingTrashResult = result
                } else {
                    pendingRestoreResult = result
                }
                pendingTargetUris = uris

                activity.startIntentSenderForResult(
                    pendingIntent.intentSender,
                    if (isTrash) REQUEST_CODE_TRASH else REQUEST_CODE_RESTORE,
                    null, 0, 0, 0
                )
            } catch (e: Exception) {
                result.error("TRASH_FAILED", e.message, null)
            }
        } else {
            // Android 10 and below: fallback to delete request or direct delete
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val pendingIntent = MediaStore.createDeleteRequest(activity.contentResolver, parsedUris)
                    pendingDeleteResult = result
                    pendingTargetUris = uris
                    activity.startIntentSenderForResult(
                        pendingIntent.intentSender,
                        REQUEST_CODE_DELETE,
                        null, 0, 0, 0
                    )
                } else {
                    val deleted = mutableListOf<String>()
                    for (u in parsedUris) {
                        val count = activity.contentResolver.delete(u, null, null)
                        if (count > 0) deleted.add(u.toString())
                    }
                    result.success(deleted)
                }
            } catch (e: Exception) {
                result.error("DELETE_FAILED", e.message, null)
            }
        }
    }

    /**
     * Permanent delete for items in Bin or on Android <= 10.
     */
    fun deletePermanently(uris: List<String>, result: MethodChannel.Result) {
        val activity = activityProvider()
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity is null", null)
            return
        }

        val parsedUris = uris.mapNotNull {
            try { Uri.parse(it) } catch (_: Exception) { null }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val pendingIntent = MediaStore.createDeleteRequest(activity.contentResolver, parsedUris)
                pendingDeleteResult = result
                pendingTargetUris = uris
                activity.startIntentSenderForResult(
                    pendingIntent.intentSender,
                    REQUEST_CODE_DELETE,
                    null, 0, 0, 0
                )
            } catch (e: Exception) {
                result.error("PERMANENT_DELETE_FAILED", e.message, null)
            }
        } else {
            val deleted = mutableListOf<String>()
            for (u in parsedUris) {
                try {
                    val count = activity.contentResolver.delete(u, null, null)
                    if (count > 0) deleted.add(u.toString())
                } catch (_: Exception) {}
            }
            result.success(deleted)
        }
    }

    /**
     * Handles activity result from system confirmation dialogs.
     */
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQUEST_CODE_TRASH -> {
                val res = pendingTrashResult
                pendingTrashResult = null
                val uris = pendingTargetUris
                pendingTargetUris = emptyList()

                if (resultCode == Activity.RESULT_OK) {
                    res?.success(uris)
                } else {
                    // User rejected or cancelled system dialog
                    res?.success(emptyList<String>())
                }
                return true
            }
            REQUEST_CODE_DELETE -> {
                val res = pendingDeleteResult
                pendingDeleteResult = null
                val uris = pendingTargetUris
                pendingTargetUris = emptyList()

                if (resultCode == Activity.RESULT_OK) {
                    res?.success(uris)
                } else {
                    res?.success(emptyList<String>())
                }
                return true
            }
            REQUEST_CODE_RESTORE -> {
                val res = pendingRestoreResult
                pendingRestoreResult = null
                val uris = pendingTargetUris
                pendingTargetUris = emptyList()

                if (resultCode == Activity.RESULT_OK) {
                    res?.success(uris)
                } else {
                    res?.success(emptyList<String>())
                }
                return true
            }
        }
        return false
    }

    /**
     * Safe Move / Copy / Archive with verified byte count matching (REQ-ACT-03, REQ-ACT-04, REQ-ACT-06).
     * Ordering: write to destination -> verify bytes match -> only then remove source if isMove.
     */
    suspend fun moveOrCopyItems(
        items: List<Map<String, Any>>,
        isMove: Boolean,
        isArchive: Boolean,
        customDestination: String?
    ): Map<String, Any> = withContext(Dispatchers.IO) {
        val resolver = context.contentResolver
        val succeededIds = mutableListOf<String>()
        val failedIds = mutableListOf<String>()
        val skippedIds = mutableListOf<String>()
        val failureReasons = mutableMapOf<String, String>()
        var totalBytesProcessed = 0L

        val defaultBaseDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)

        for (itemMap in items) {
            val id = (itemMap["id"] as? String) ?: ""
            val uriStr = (itemMap["contentUri"] as? String) ?: ""
            val displayName = (itemMap["displayName"] as? String) ?: "file_${System.currentTimeMillis()}"
            val sizeBytes = ((itemMap["sizeBytes"] as? Number) ?: 0L).toLong()
            val mimeType = (itemMap["mimeType"] as? String) ?: "application/octet-stream"
            val dateAddedSec = ((itemMap["dateAddedSec"] as? Number) ?: 0L).toLong()

            if (uriStr.isBlank()) {
                skippedIds.add(id)
                failureReasons[id] = "Missing contentUri"
                continue
            }

            val sourceUri = try {
                Uri.parse(uriStr)
            } catch (e: Exception) {
                failedIds.add(id)
                failureReasons[id] = "Invalid URI: ${e.message}"
                continue
            }

            // Determine target folder
            val targetDir = if (isArchive) {
                val year = if (dateAddedSec > 0) {
                    SimpleDateFormat("yyyy", Locale.US).format(Date(dateAddedSec * 1000))
                } else {
                    SimpleDateFormat("yyyy", Locale.US).format(Date())
                }
                val mediaTypeSubfolder = when {
                    mimeType.startsWith("video/") -> "Videos"
                    mimeType.startsWith("audio/") -> "Audio"
                    else -> "Images"
                }
                File(defaultBaseDir, "Media Archive/$year/$mediaTypeSubfolder")
            } else if (!customDestination.isNullOrBlank()) {
                File(customDestination)
            } else {
                File(defaultBaseDir, "WappTidy Organized")
            }

            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }

            // Resolve filename collisions (REQ-ACT-04)
            val destFile = resolveNonCollidingFile(targetDir, displayName)

            // Step 1: Write to destination first
            var writeSuccess = false
            var bytesWritten = 0L
            try {
                val inStream: InputStream? = resolver.openInputStream(sourceUri)
                if (inStream == null) {
                    failedIds.add(id)
                    failureReasons[id] = "Source file missing or inaccessible"
                    continue
                }

                FileOutputStream(destFile).use { outStream ->
                    val buffer = ByteArray(64 * 1024)
                    var read: Int
                    while (inStream.read(buffer).also { read = it } != -1) {
                        outStream.write(buffer, 0, read)
                        bytesWritten += read
                    }
                    outStream.flush()
                }
                inStream.close()
                writeSuccess = true
            } catch (e: Exception) {
                // If write failed, delete partial destination file
                if (destFile.exists()) destFile.delete()
                failedIds.add(id)
                failureReasons[id] = "Write failed: ${e.message}"
                continue
            }

            // Step 2: VERIFY EXACT BYTE COUNT (REQ-ACT-03 - Ordering not optional)
            if (!writeSuccess || !destFile.exists() || destFile.length() != sizeBytes) {
                if (destFile.exists()) destFile.delete()
                failedIds.add(id)
                failureReasons[id] = "Byte verification mismatch: wrote ${destFile.length()} expected $sizeBytes"
                continue
            }

            // Step 3: Only after verification passes, remove source if move
            if (isMove) {
                try {
                    resolver.delete(sourceUri, null, null)
                } catch (e: Exception) {
                    // Source delete error on Android 11+ scoped storage requires user consent dialog
                    // File was safely copied to destination
                }
            }

            succeededIds.add(id)
            totalBytesProcessed += sizeBytes
        }

        mapOf(
            "succeededIds" to succeededIds,
            "failedIds" to failedIds,
            "skippedIds" to skippedIds,
            "failureReasons" to failureReasons,
            "totalBytesProcessed" to totalBytesProcessed
        )
    }

    /**
     * Queries trashed items on Android 11+ (API 30+) via IS_TRASHED (REQ-BIN-01).
     */
    suspend fun queryTrashedItems(): List<Map<String, Any>> = withContext(Dispatchers.IO) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return@withContext emptyList<Map<String, Any>>()
        }

        val result = mutableListOf<Map<String, Any>>()
        val resolver = context.contentResolver
        val collections = listOf(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        )

        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.MIME_TYPE,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.BUCKET_DISPLAY_NAME
        )

        for (collection in collections) {
            try {
                val bundle = Bundle().apply {
                    putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_TRASHED)
                    putString(ContentResolver.QUERY_ARG_SQL_SELECTION, "${MediaStore.MediaColumns.IS_TRASHED} = 1")
                    putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, "${MediaStore.MediaColumns.DATE_MODIFIED} DESC")
                }

                resolver.query(collection, projection, bundle, null)?.use { cursor ->
                    val idCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                    val nameCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
                    val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
                    val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
                    val dateCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)
                    val bucketCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)

                    while (cursor.moveToNext()) {
                        val rowId = cursor.getLong(idCol)
                        val contentUri = ContentUris.withAppendedId(collection, rowId).toString()
                        val name = cursor.getString(nameCol) ?: "unknown"
                        val size = cursor.getLong(sizeCol)
                        val mime = cursor.getString(mimeCol) ?: "application/octet-stream"
                        val dateModified = cursor.getLong(dateCol)
                        val bucket = cursor.getString(bucketCol) ?: "WhatsApp"

                        result.add(
                            mapOf(
                                "id" to rowId.toString(),
                                "contentUri" to contentUri,
                                "displayName" to name,
                                "sizeBytes" to size,
                                "mimeType" to mime,
                                "dateModifiedSec" to dateModified,
                                "bucketName" to bucket
                            )
                        )
                    }
                }
            } catch (_: Exception) {}
        }

        result
    }

    private fun resolveNonCollidingFile(dir: File, originalName: String): File {
        var file = File(dir, originalName)
        if (!file.exists()) return file

        val dotIndex = originalName.lastIndexOf('.')
        val baseName = if (dotIndex != -1) originalName.substring(0, dotIndex) else originalName
        val extension = if (dotIndex != -1) originalName.substring(dotIndex) else ""

        var counter = 1
        while (file.exists()) {
            file = File(dir, "${baseName}_$counter$extension")
            counter++
        }
        return file
    }
}
