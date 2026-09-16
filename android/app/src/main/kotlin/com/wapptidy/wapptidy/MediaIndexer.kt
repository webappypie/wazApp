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
    "WhatsApp Documents",
    "WhatsApp Animated Gifs",
    "WhatsApp Stickers",
    "WhatsApp Profile Photos",
    "WhatsApp Business Images",
    "WhatsApp Business Video",
    "WhatsApp Business Audio",
    // Legacy bucket names
    "WhatsApp",
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

    // State for resume: last dateModified cursor position.
    private val resumeCursor = AtomicReference<Long>(0L)

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
     */
    fun startIndex(
        sinceModifiedSec: Long = 0L,
        scanVersion: Int = 1,
        generationSince: Long = 0L,
    ) {
        isPaused.set(false)
        isCancelled.set(false)
        currentJob?.cancel()
        currentJob = scope.launch {
            runIndex(sinceModifiedSec, scanVersion, generationSince)
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
    ) {
        var itemsProcessed = 0
        var bytesProcessed = 0L
        var itemsTotal = 0

        try {
            // Query all three content types and interleave results.
            val uris = buildList {
                add(Triple(
                    getMediaUri(MediaStore.Files.getContentUri("external")),
                    "image",
                    null,
                ))
            }

            val contentUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
            } else {
                @Suppress("DEPRECATION")
                MediaStore.Files.getContentUri("external")
            }

            val projection = buildProjection()
            val selection = buildSelection(sinceModifiedSec, generationSince)
            val selectionArgs = buildSelectionArgs(sinceModifiedSec, generationSince)
            val sortOrder = "${MediaStore.Files.FileColumns.DATE_MODIFIED} ASC"

            val cursor = context.contentResolver.query(
                contentUri,
                projection,
                selection,
                selectionArgs,
                sortOrder,
            ) ?: run {
                sendEvent(mapOf(
                    "status" to ScanStatus.ERROR,
                    "error" to "ContentResolver returned null cursor",
                ))
                return
            }

            cursor.use { c ->
                itemsTotal = c.count
                sendProgress(itemsProcessed, itemsTotal, bytesProcessed, scanVersion)

                val batch = mutableListOf<Map<String, Any?>>()

                while (c.moveToNext()) {
                    // Honour pause/cancel between rows (REQ-IDX-04).
                    while (isPaused.get() && !isCancelled.get()) {
                        sendEvent(mapOf(
                            "status"         to ScanStatus.PAUSED,
                            "itemsProcessed" to itemsProcessed,
                            "itemsTotal"     to itemsTotal,
                            "bytesProcessed" to bytesProcessed,
                        ))
                        delay(500)
                    }
                    if (isCancelled.get()) {
                        sendEvent(mapOf("status" to ScanStatus.CANCELLED))
                        return
                    }

                    // REQ-IDX-07: skip rows we can't read without aborting.
                    val row = tryReadRow(c, scanVersion) ?: continue

                    // Only emit rows that belong to a known WhatsApp bucket.
                    val bucketName = row["bucketName"] as? String ?: ""
                    if (!isWhatsAppBucket(bucketName, row["relativePath"] as? String)) {
                        continue
                    }

                    val sizeBytes = (row["sizeBytes"] as? Long) ?: 0L
                    batch.add(row)
                    bytesProcessed += sizeBytes
                    itemsProcessed++

                    // Record cursor for resume (REQ-IDX-04).
                    resumeCursor.set((row["dateModifiedSec"] as? Long) ?: 0L)

                    if (batch.size >= BATCH_SIZE) {
                        sendEvent(mapOf(
                            "status"         to ScanStatus.PROGRESS,
                            "items"          to batch.toList(),
                            "itemsProcessed" to itemsProcessed,
                            "itemsTotal"     to itemsTotal,
                            "bytesProcessed" to bytesProcessed,
                            "scanVersion"    to scanVersion,
                        ))
                        batch.clear()
                    }
                }

                // Flush remaining items.
                if (batch.isNotEmpty()) {
                    sendEvent(mapOf(
                        "status"         to ScanStatus.PROGRESS,
                        "items"          to batch.toList(),
                        "itemsProcessed" to itemsProcessed,
                        "itemsTotal"     to itemsTotal,
                        "bytesProcessed" to bytesProcessed,
                        "scanVersion"    to scanVersion,
                    ))
                }
            }

            sendEvent(mapOf(
                "status"         to ScanStatus.DONE,
                "itemsProcessed" to itemsProcessed,
                "itemsTotal"     to itemsTotal,
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
        add(MediaStore.Files.FileColumns._ID)
        add(MediaStore.Files.FileColumns.DISPLAY_NAME)
        add(MediaStore.Files.FileColumns.MIME_TYPE)
        add(MediaStore.Files.FileColumns.SIZE)
        add(MediaStore.Files.FileColumns.DATE_ADDED)
        add(MediaStore.Files.FileColumns.DATE_MODIFIED)
        add(MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME)
        add(MediaStore.Files.FileColumns.WIDTH)
        add(MediaStore.Files.FileColumns.HEIGHT)
        add(MediaStore.Files.FileColumns.DURATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            add(MediaStore.Files.FileColumns.RELATIVE_PATH)
        }
    }.toTypedArray()

    private fun buildSelection(sinceModifiedSec: Long, generationSince: Long): String? {
        val clauses = mutableListOf<String>()

        // Only media files (images, video, audio) — exclude documents by MIME prefix.
        clauses.add(
            "(${MediaStore.Files.FileColumns.MIME_TYPE} LIKE 'image/%' " +
            "OR ${MediaStore.Files.FileColumns.MIME_TYPE} LIKE 'video/%' " +
            "OR ${MediaStore.Files.FileColumns.MIME_TYPE} LIKE 'audio/%')"
        )

        if (sinceModifiedSec > 0L) {
            clauses.add("${MediaStore.Files.FileColumns.DATE_MODIFIED} >= ?")
        }

        if (generationSince > 0L && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            clauses.add("${MediaStore.Files.FileColumns.GENERATION_MODIFIED} > ?")
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
     * Read one row safely. Returns null if any required field is missing
     * or throws (REQ-IDX-07: file disappearing mid-scan must not abort the batch).
     */
    private fun tryReadRow(cursor: Cursor, scanVersion: Int): Map<String, Any?>? {
        return try {
            val mediaStoreId = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID))
            val contentUri = ContentUris.withAppendedId(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                    MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
                else
                    @Suppress("DEPRECATION") MediaStore.Files.getContentUri("external"),
                mediaStoreId,
            ).toString()

            val displayName = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)) ?: ""
            val mimeType    = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)) ?: ""
            val sizeBytes   = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE))
            val dateAdded   = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_ADDED))
            val dateModified = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED))
            val bucketName  = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME)) ?: ""
            val width       = cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.WIDTH))
            val height      = cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.HEIGHT))
            val duration    = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DURATION))
            val relativePath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.RELATIVE_PATH)) ?: ""
            } else ""

            val sourceApp = resolveSourceApp(bucketName, relativePath)

            mapOf(
                "contentUri"      to contentUri,
                "mediaStoreId"    to mediaStoreId.toString(),
                "displayName"     to displayName,
                "mimeType"        to mimeType,
                "sizeBytes"       to sizeBytes,
                "dateAddedSec"    to dateAdded,
                "dateModifiedSec" to dateModified,
                "bucketName"      to bucketName,
                "relativePath"    to relativePath,
                "width"           to width,
                "height"          to height,
                "durationMs"      to duration,
                "sourceApp"       to sourceApp,
                "scanVersion"     to scanVersion,
            )
        } catch (e: Exception) {
            // REQ-IDX-07: log and skip — don't abort the whole scan.
            null
        }
    }

    private fun isWhatsAppBucket(bucketName: String, relativePath: String?): Boolean {
        if (WHATSAPP_BUCKETS.any { it.equals(bucketName, ignoreCase = true) }) return true
        // Legacy path check: /WhatsApp/ in relative_path or absolute path.
        val path = relativePath ?: ""
        return path.contains("WhatsApp", ignoreCase = true)
    }

    private fun resolveSourceApp(bucketName: String, relativePath: String): String {
        val combined = "$bucketName $relativePath".lowercase()
        return if (combined.contains("business")) SOURCE_WHATSAPP_BUSINESS
               else SOURCE_WHATSAPP
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
