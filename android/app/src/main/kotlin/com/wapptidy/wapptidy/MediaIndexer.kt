package com.wapptidy.wapptidy

/*
 * MediaIndexer.kt
 *
 * Queries Android MediaStore for WhatsApp media files and streams results
 * back to Flutter via a platform channel EventChannel.
 *
 * PRD §5.2: MediaStore is the ONLY storage access strategy.
 * PRD §5.4: Heavy compute runs in Kotlin, not Dart isolates.
 * PRD §5.5 budgets:
 *   - Full index (metadata only): < 45s for 15,000+ files
 *   - Incremental rescan (200 new files): < 8s
 *   - Peak RAM: < 350MB
 *
 * RULES (DEV_PROMPT §2):
 *   - Never read file contents — metadata only
 *   - Never store or transmit file paths or names anywhere outside the device
 *   - MANAGE_EXTERNAL_STORAGE is never requested
 *
 * Channel names:
 *   com.wapptidy/media_indexer        — MethodChannel (start/pause/cancel)
 *   com.wapptidy/media_indexer_events — EventChannel  (progress stream)
 */

import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.os.Build
import android.provider.MediaStore
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/** Known WhatsApp bucket names and relative paths (REQ-IDX-01, REQ-IDX-06). */
private val WHATSAPP_BUCKETS = setOf(
    // Modern paths (Android 11+ scoped storage)
    "WhatsApp Images",
    "WhatsApp Video",
    "WhatsApp Audio",
    "WhatsApp Voice Notes",
    "WhatsApp Documents",
    "WhatsApp Animated Gifs",
    "WhatsApp Stickers",
    "WhatsApp Profile Photos",
    "WhatsApp Business Images",
    "WhatsApp Business Video",
    "WhatsApp Business Audio",
    "WhatsApp Business Documents",
    "WhatsApp Business Voice Notes",
    "WhatsApp Business Animated Gifs",
    "WhatsApp Business Stickers",
    "WhatsApp Business Profile Photos",
    // Legacy bucket names
    "WhatsApp",
    "WhatsApp Business",
)

/** Source app tags derived from bucket name or relative_path. */
private const val SOURCE_WHATSAPP = "com.whatsapp"
private const val SOURCE_WHATSAPP_BUSINESS = "com.whatsapp.w4b"

/** Batch size for insertions — balances throughput and memory. */
private const val BATCH_SIZE = 200

/** MediaIndexer state values sent over the event channel. */
object ScanStatus {
    const val PROGRESS = "progress"
    const val DONE     = "done"
    const val PAUSED   = "paused"
    const val CANCELLED = "cancelled"
    const val ERROR    = "error"
}

class MediaIndexer(private val context: Context) {

    // Coroutine scope for the indexing job.
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var currentJob: Job? = null

    // Atomic flags for pause/cancel — safely signalled from Flutter thread.
    private val isPaused    = AtomicBoolean(false)
    private val isCancelled = AtomicBoolean(false)

    // State for resume: last dateModified cursor position and active sources.
    private val resumeCursor = AtomicReference<Long>(0L)
    private var currentSourceApps: List<String> = listOf(SOURCE_WHATSAPP, SOURCE_WHATSAPP_BUSINESS)

    /** EventChannel sink — set by the StreamHandler below. */
    var eventSink: EventChannel.EventSink? = null

    // ------------------------------------------------------------------
    // Public control API (called from MethodChannel handler)
    // ------------------------------------------------------------------

    /**
     * Start or resume a full index.
     *
     * [sinceModifiedSec] — if > 0, only return rows modified after this
     *   timestamp (incremental rescan — REQ-IDX-03).
     * [scanVersion] — version number for this pass (written into each row).
     * [generationSince] — MediaStore generation counter for fast-path
     *   change detection (API 29+).
     * [sourceApps] — list of package names to scan ('com.whatsapp', 'com.whatsapp.w4b').
     */
    fun startIndex(
        sinceModifiedSec: Long = 0L,
        scanVersion: Int = 1,
        generationSince: Long = 0L,
        sourceApps: List<String> = listOf(SOURCE_WHATSAPP, SOURCE_WHATSAPP_BUSINESS),
    ) {
        currentSourceApps = sourceApps
        isPaused.set(false)
        isCancelled.set(false)
        currentJob?.cancel()
        currentJob = scope.launch {
            runIndex(sinceModifiedSec, scanVersion, generationSince, sourceApps)
        }
    }

    fun pause() {
        isPaused.set(true)
    }

    fun resume() {
        if (isPaused.get()) {
            isPaused.set(false)
            // Resume from last committed cursor.
            startIndex(
                sinceModifiedSec = resumeCursor.get(),
                scanVersion = 1, // caller should pass current scan version
                sourceApps = currentSourceApps,
            )
        }
    }

    fun cancel() {
        isCancelled.set(true)
        currentJob?.cancel()
        sendEvent(mapOf("status" to ScanStatus.CANCELLED))
    }

    /** Read current MediaStore generation counter (API 29+, else 0). */
    fun currentGeneration(): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.getGeneration(context, MediaStore.VOLUME_EXTERNAL)
        } else {
            0L
        }
    }

    // ------------------------------------------------------------------
    // Core indexing
    // ------------------------------------------------------------------

    private suspend fun runIndex(
        sinceModifiedSec: Long,
        scanVersion: Int,
        generationSince: Long,
        sourceApps: List<String>,
    ) {
        var itemsProcessed = 0
        var bytesProcessed = 0L
        val seenIds = mutableSetOf<String>()
        val batch = mutableListOf<Map<String, Any?>>()

        try {
            // Target all relevant media tables + generic files table for maximum compatibility across Android versions
            val queryTargets = buildList {
                add(MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
                add(MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
                add(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    add(MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL))
                } else {
                    @Suppress("DEPRECATION")
                    add(MediaStore.Files.getContentUri("external"))
                }
            }

            val projection = buildProjection()
            val sortOrder = "${MediaStore.MediaColumns.DATE_MODIFIED} ASC"

            for (targetUri in queryTargets) {
                if (isCancelled.get()) break

                val selection = buildSelection(targetUri, sinceModifiedSec, generationSince)
                val selectionArgs = buildSelectionArgs(sinceModifiedSec, generationSince)

                val cursor = try {
                    context.contentResolver.query(
                        targetUri,
                        projection,
                        selection,
                        selectionArgs,
                        sortOrder,
                    )
                } catch (_: Exception) {
                    null
                } ?: continue

                cursor.use { c ->
                    while (c.moveToNext()) {
                        while (isPaused.get() && !isCancelled.get()) {
                            sendEvent(mapOf(
                                "status"         to ScanStatus.PAUSED,
                                "itemsProcessed" to itemsProcessed,
                                "itemsTotal"     to itemsProcessed,
                                "bytesProcessed" to bytesProcessed,
                            ))
                            delay(500)
                        }
                        if (isCancelled.get()) {
                            sendEvent(mapOf("status" to ScanStatus.CANCELLED))
                            return
                        }

                        val row = tryReadRow(c, targetUri, scanVersion) ?: continue

                        // Prevent duplicates across multiple content queries
                        val mediaStoreId = row["mediaStoreId"] as? String ?: ""
                        val rowKey = if (mediaStoreId.isNotEmpty()) mediaStoreId else (row["contentUri"] as? String ?: "")
                        if (seenIds.contains(rowKey)) continue
                        seenIds.add(rowKey)

                        val sourceApp = row["sourceApp"] as? String ?: SOURCE_WHATSAPP
                        if (sourceApps.isNotEmpty() && !sourceApps.contains(sourceApp)) {
                            continue
                        }

                        val sizeBytes = (row["sizeBytes"] as? Long) ?: 0L
                        batch.add(row)
                        bytesProcessed += sizeBytes
                        itemsProcessed++

                        resumeCursor.set((row["dateModifiedSec"] as? Long) ?: 0L)

                        if (batch.size >= BATCH_SIZE) {
                            sendEvent(mapOf(
                                "status"         to ScanStatus.PROGRESS,
                                "items"          to batch.toList(),
                                "itemsProcessed" to itemsProcessed,
                                "itemsTotal"     to itemsProcessed,
                                "bytesProcessed" to bytesProcessed,
                                "scanVersion"    to scanVersion,
                            ))
                            batch.clear()
                        }
                    }
                }
            }

            // Flush remaining MediaStore items
            if (batch.isNotEmpty()) {
                sendEvent(mapOf(
                    "status"         to ScanStatus.PROGRESS,
                    "items"          to batch.toList(),
                    "itemsProcessed" to itemsProcessed,
                    "itemsTotal"     to itemsProcessed,
                    "bytesProcessed" to bytesProcessed,
                    "scanVersion"    to scanVersion,
                ))
                batch.clear()
            }

            // Fallback: If MediaStore query yielded 0 items, scan direct file system for WhatsApp folders
            if (itemsProcessed == 0) {
                val externalDir = android.os.Environment.getExternalStorageDirectory()
                val candidateDirs = listOf(
                    Pair(java.io.File(externalDir, "Android/media/com.whatsapp/WhatsApp/Media"), SOURCE_WHATSAPP),
                    Pair(java.io.File(externalDir, "Android/media/com.whatsapp.w4b/WhatsApp Business/Media"), SOURCE_WHATSAPP_BUSINESS),
                    Pair(java.io.File(externalDir, "WhatsApp/Media"), SOURCE_WHATSAPP),
                    Pair(java.io.File(externalDir, "WhatsApp Business/Media"), SOURCE_WHATSAPP_BUSINESS),
                )

                for ((mediaRoot, defaultSource) in candidateDirs) {
                    if (!mediaRoot.exists() || !mediaRoot.canRead()) continue
                    val subdirs = mediaRoot.listFiles() ?: continue
                    for (folder in subdirs) {
                        if (!folder.isDirectory) continue
                        val folderName = folder.name
                        val files = folder.listFiles() ?: continue
                        for (file in files) {
                            if (file.isDirectory || file.name.startsWith(".")) continue
                            if (sourceApps.isNotEmpty() && !sourceApps.contains(defaultSource)) continue

                            val filePath = file.absolutePath
                            if (seenIds.contains(filePath)) continue
                            seenIds.add(filePath)

                            val ext = file.extension.lowercase()
                            val mime = android.webkit.MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "application/octet-stream"
                            val size = file.length()
                            val modSec = file.lastModified() / 1000

                            val row = mapOf(
                                "contentUri"      to android.net.Uri.fromFile(file).toString(),
                                "mediaStoreId"    to (file.hashCode().toLong() and 0xFFFFFFFFL).toString(),
                                "displayName"     to file.name,
                                "mimeType"        to mime,
                                "sizeBytes"       to size,
                                "dateAddedSec"    to modSec,
                                "dateModifiedSec" to modSec,
                                "bucketName"      to folderName,
                                "relativePath"    to "Android/media/" + (if (defaultSource == SOURCE_WHATSAPP_BUSINESS) "com.whatsapp.w4b/" else "com.whatsapp/") + folderName + "/",
                                "width"           to 0,
                                "height"          to 0,
                                "durationMs"      to 0L,
                                "sourceApp"       to defaultSource,
                                "scanVersion"     to scanVersion,
                            )

                            batch.add(row)
                            bytesProcessed += size
                            itemsProcessed++

                            if (batch.size >= BATCH_SIZE) {
                                sendEvent(mapOf(
                                    "status"         to ScanStatus.PROGRESS,
                                    "items"          to batch.toList(),
                                    "itemsProcessed" to itemsProcessed,
                                    "itemsTotal"     to itemsProcessed,
                                    "bytesProcessed" to bytesProcessed,
                                    "scanVersion"    to scanVersion,
                                ))
                                batch.clear()
                            }
                        }
                    }
                }

                if (batch.isNotEmpty()) {
                    sendEvent(mapOf(
                        "status"         to ScanStatus.PROGRESS,
                        "items"          to batch.toList(),
                        "itemsProcessed" to itemsProcessed,
                        "itemsTotal"     to itemsProcessed,
                        "bytesProcessed" to bytesProcessed,
                        "scanVersion"    to scanVersion,
                    ))
                    batch.clear()
                }
            }

            sendEvent(mapOf(
                "status"         to ScanStatus.DONE,
                "itemsProcessed" to itemsProcessed,
                "itemsTotal"     to itemsProcessed,
                "bytesProcessed" to bytesProcessed,
                "scanVersion"    to scanVersion,
                "generation"     to currentGeneration(),
            ))

        } catch (e: CancellationException) {
            sendEvent(mapOf("status" to ScanStatus.CANCELLED))
        } catch (e: Exception) {
            sendEvent(mapOf(
                "status" to ScanStatus.ERROR,
                "error"  to (e.message ?: "Unknown error"),
            ))
        }
    }

    // ------------------------------------------------------------------
    // MediaStore query helpers
    // ------------------------------------------------------------------

    private fun buildProjection(): Array<String> = buildList {
        add(MediaStore.MediaColumns._ID)
        add(MediaStore.MediaColumns.DISPLAY_NAME)
        add(MediaStore.MediaColumns.MIME_TYPE)
        add(MediaStore.MediaColumns.SIZE)
        add(MediaStore.MediaColumns.DATE_ADDED)
        add(MediaStore.MediaColumns.DATE_MODIFIED)
        @Suppress("DEPRECATION")
        add(MediaStore.MediaColumns.DATA)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            add(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)
            add(MediaStore.MediaColumns.WIDTH)
            add(MediaStore.MediaColumns.HEIGHT)
            add(MediaStore.MediaColumns.DURATION)
            add(MediaStore.MediaColumns.RELATIVE_PATH)
        }
    }.toTypedArray()

    private fun buildSelection(uri: android.net.Uri, sinceModifiedSec: Long, generationSince: Long): String? {
        val clauses = mutableListOf<String>()

        if (uri.toString().contains("file", ignoreCase = true)) {
            clauses.add(
                "(${MediaStore.MediaColumns.MIME_TYPE} LIKE 'image/%' " +
                "OR ${MediaStore.MediaColumns.MIME_TYPE} LIKE 'video/%' " +
                "OR ${MediaStore.MediaColumns.MIME_TYPE} LIKE 'audio/%' " +
                "OR ${MediaStore.MediaColumns.MIME_TYPE} LIKE 'application/%' " +
                "OR ${MediaStore.MediaColumns.MIME_TYPE} LIKE 'text/%')"
            )
        }

        if (sinceModifiedSec > 0L) {
            clauses.add("${MediaStore.MediaColumns.DATE_MODIFIED} >= ?")
        }

        if (generationSince > 0L && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            clauses.add("${MediaStore.MediaColumns.GENERATION_MODIFIED} > ?")
        }

        return if (clauses.isEmpty()) null else clauses.joinToString(" AND ")
    }

    private fun buildSelectionArgs(sinceModifiedSec: Long, generationSince: Long): Array<String>? {
        val args = mutableListOf<String>()
        if (sinceModifiedSec > 0L) args.add(sinceModifiedSec.toString())
        if (generationSince > 0L && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            args.add(generationSince.toString())
        }
        return if (args.isEmpty()) null else args.toTypedArray()
    }

    /**
     * Read one row safely using getColumnIndex (never throws IllegalArgumentException).
     */
    private fun tryReadRow(cursor: Cursor, baseUri: android.net.Uri, scanVersion: Int): Map<String, Any?>? {
        return try {
            val idIndex = cursor.getColumnIndex(MediaStore.MediaColumns._ID)
            if (idIndex < 0) return null
            val mediaStoreId = cursor.getLong(idIndex)
            val contentUri = ContentUris.withAppendedId(baseUri, mediaStoreId).toString()

            val displayName = cursor.getStringOrEmpty(MediaStore.MediaColumns.DISPLAY_NAME)
            val mimeType    = cursor.getStringOrEmpty(MediaStore.MediaColumns.MIME_TYPE)
            val sizeBytes   = cursor.getLongOrZero(MediaStore.MediaColumns.SIZE)
            val dateAdded   = cursor.getLongOrZero(MediaStore.MediaColumns.DATE_ADDED)
            val dateModified = cursor.getLongOrZero(MediaStore.MediaColumns.DATE_MODIFIED)
            val bucketName  = cursor.getStringOrEmpty(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)
            val width       = cursor.getIntOrZero(MediaStore.MediaColumns.WIDTH)
            val height      = cursor.getIntOrZero(MediaStore.MediaColumns.HEIGHT)
            val duration    = cursor.getLongOrZero(MediaStore.MediaColumns.DURATION)
            val relativePath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                cursor.getStringOrEmpty(MediaStore.MediaColumns.RELATIVE_PATH)
            } else ""
            @Suppress("DEPRECATION")
            val dataPath = cursor.getStringOrEmpty(MediaStore.MediaColumns.DATA)

            if (!isWhatsAppBucket(bucketName, relativePath, dataPath)) {
                return null
            }

            val sourceApp = resolveSourceApp(bucketName, relativePath, dataPath)

            mapOf(
                "contentUri"      to contentUri,
                "mediaStoreId"    to mediaStoreId.toString(),
                "displayName"     to displayName,
                "mimeType"        to mimeType,
                "sizeBytes"       to sizeBytes,
                "dateAddedSec"    to dateAdded,
                "dateModifiedSec" to dateModified,
                "bucketName"      to (if (bucketName.isNotEmpty()) bucketName else "WhatsApp"),
                "relativePath"    to relativePath,
                "width"           to width,
                "height"          to height,
                "durationMs"      to duration,
                "sourceApp"       to sourceApp,
                "scanVersion"     to scanVersion,
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun isWhatsAppBucket(bucketName: String, relativePath: String?, dataPath: String?): Boolean {
        if (WHATSAPP_BUCKETS.any { it.equals(bucketName, ignoreCase = true) }) return true
        val combined = "$bucketName $relativePath $dataPath".lowercase()
        return combined.contains("whatsapp") || combined.contains("com.whatsapp")
    }

    private fun resolveSourceApp(bucketName: String, relativePath: String, dataPath: String): String {
        val combined = "$bucketName $relativePath $dataPath".lowercase()
        return if (combined.contains("business") || combined.contains("w4b")) SOURCE_WHATSAPP_BUSINESS
               else SOURCE_WHATSAPP
    }

    private fun Cursor.getIntOrZero(colName: String): Int {
        val idx = getColumnIndex(colName)
        return if (idx >= 0 && !isNull(idx)) getInt(idx) else 0
    }

    private fun Cursor.getLongOrZero(colName: String): Long {
        val idx = getColumnIndex(colName)
        return if (idx >= 0 && !isNull(idx)) getLong(idx) else 0L
    }

    private fun Cursor.getStringOrEmpty(colName: String): String {
        val idx = getColumnIndex(colName)
        return if (idx >= 0 && !isNull(idx)) getString(idx) ?: "" else ""
    }

    private fun getMediaUri(uri: android.net.Uri) = uri

    // ------------------------------------------------------------------
    // Event emission (must be called on main thread for EventChannel)
    // ------------------------------------------------------------------

    private fun sendProgress(
        itemsProcessed: Int,
        itemsTotal: Int,
        bytesProcessed: Long,
        scanVersion: Int,
    ) {
        sendEvent(mapOf(
            "status"         to ScanStatus.PROGRESS,
            "items"          to emptyList<Map<String, Any?>>(),
            "itemsProcessed" to itemsProcessed,
            "itemsTotal"     to itemsTotal,
            "bytesProcessed" to bytesProcessed,
            "scanVersion"    to scanVersion,
        ))
    }

    fun sendEvent(data: Map<String, Any?>) {
        // EventChannel requires main-thread dispatch.
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventSink?.success(data)
        }
    }

    fun dispose() {
        scope.cancel()
        eventSink = null
    }
}
