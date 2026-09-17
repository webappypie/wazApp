package com.wapptidy.wapptidy

/*
 * MainActivity.kt
 *
 * Registers platform channels:
 *   - com.wapptidy/media_indexer        (MethodChannel)  — control: start/pause/cancel/generation
 *   - com.wapptidy/media_indexer_events (EventChannel)   — streaming progress updates
 *   - com.wapptidy/duplicate_detector   (MethodChannel)  — 2-stage exact hash duplicate detection
 *
 * PRD §5.4: All heavy MediaStore and hashing work happens in Kotlin,
 * not in Dart isolates.
 */

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

import androidx.core.app.NotificationManagerCompat
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL    = "com.wapptidy/media_indexer"
        private const val EVENT_CHANNEL     = "com.wapptidy/media_indexer_events"
        private const val DUPLICATE_CHANNEL = "com.wapptidy/duplicate_detector"
        private const val ACTIONS_CHANNEL   = "com.wapptidy/media_actions"
        private const val SIMILAR_CHANNEL   = "com.wapptidy/perceptual_hash"
        private const val BLUR_CHANNEL      = "com.wapptidy/blur_detector"
        private const val COMPRESSOR_CHANNEL = "com.wapptidy/video_compressor"
        private const val COMPRESSOR_EVENTS  = "com.wapptidy/video_compressor_events"
        private const val BACKGROUND_CHANNEL = "com.wapptidy/background_work"
        private const val NOTIFICATION_CHANNEL = "com.wapptidy/notifications"
    }

    private lateinit var mediaIndexer: MediaIndexer
    private lateinit var duplicateDetector: DuplicateDetector
    private lateinit var mediaActionHandler: MediaActionHandler
    private lateinit var perceptualHashEngine: PerceptualHashEngine
    private lateinit var blurDetectorEngine: BlurDetectorEngine
    private lateinit var videoCompressorEngine: VideoCompressorEngine
    private var compressorEventSink: EventChannel.EventSink? = null
    private val scope = CoroutineScope(Dispatchers.Main)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaIndexer = MediaIndexer(applicationContext)
        duplicateDetector = DuplicateDetector(applicationContext)
        mediaActionHandler = MediaActionHandler(applicationContext) { this }
        perceptualHashEngine = PerceptualHashEngine(applicationContext)

        // --- MethodChannel: indexer control commands ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startIndex" -> {
                        val sinceModifiedSec = (call.argument<Number>("sinceModifiedSec") ?: 0).toLong()
                        val scanVersion      = (call.argument<Number>("scanVersion") ?: 1).toInt()
                        val generationSince  = (call.argument<Number>("generationSince") ?: 0L).toLong()
                        mediaIndexer.startIndex(sinceModifiedSec, scanVersion, generationSince)
                        result.success(null)
                    }
                    "pause" -> {
                        mediaIndexer.pause()
                        result.success(null)
                    }
                    "resume" -> {
                        mediaIndexer.resume()
                        result.success(null)
                    }
                    "cancel" -> {
                        mediaIndexer.cancel()
                        result.success(null)
                    }
                    "currentGeneration" -> {
                        result.success(mediaIndexer.currentGeneration())
                    }
                    else -> result.notImplemented()
                }
            }

        // --- EventChannel: indexer progress stream ---
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    mediaIndexer.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    mediaIndexer.eventSink = null
                }
            })

        // --- MethodChannel: duplicate detector (PRD §5.4, REQ-DUP-01) ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DUPLICATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "findDuplicates") {
                    val rawItems = call.argument<List<Map<String, Any>>>("items") ?: emptyList()
                    val candidates = rawItems.map { map ->
                        CandidateItem(
                            id = (map["id"] as? String) ?: "",
                            contentUri = (map["contentUri"] as? String) ?: "",
                            displayName = (map["displayName"] as? String) ?: "",
                            mimeType = (map["mimeType"] as? String) ?: "",
                            sizeBytes = ((map["sizeBytes"] as? Number) ?: 0L).toLong(),
                            dateAddedSec = ((map["dateAddedSec"] as? Number) ?: 0L).toLong(),
                            dateModifiedSec = ((map["dateModifiedSec"] as? Number) ?: 0L).toLong(),
                            bucketName = (map["bucketName"] as? String) ?: "",
                            sourceApp = (map["sourceApp"] as? String) ?: "",
                            width = ((map["width"] as? Number) ?: 0).toInt(),
                            height = ((map["height"] as? Number) ?: 0).toInt(),
                            durationMs = ((map["durationMs"] as? Number) ?: 0).toInt(),
                            isProtected = (map["isProtected"] as? Boolean) ?: false
                        )
                    }

                    scope.launch {
                        try {
                            val duplicates = duplicateDetector.findDuplicates(candidates)
                            result.success(duplicates)
                        } catch (e: Exception) {
                            result.error("DUPLICATE_ERROR", e.message, null)
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }

        // --- MethodChannel: media actions (Phase 7: REQ-ACT-01..07, REQ-BIN-01..05) ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACTIONS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidVersion" -> {
                        result.success(mediaActionHandler.getAndroidVersion())
                    }
                    "trashItems" -> {
                        val uris = call.argument<List<String>>("uris") ?: emptyList()
                        val isTrash = call.argument<Boolean>("isTrash") ?: true
                        mediaActionHandler.trashItems(uris, isTrash, result)
                    }
                    "deletePermanently" -> {
                        val uris = call.argument<List<String>>("uris") ?: emptyList()
                        mediaActionHandler.deletePermanently(uris, result)
                    }
                    "moveOrCopyItems" -> {
                        val rawItems = call.argument<List<Map<String, Any>>>("items") ?: emptyList()
                        val isMove = call.argument<Boolean>("isMove") ?: false
                        val isArchive = call.argument<Boolean>("isArchive") ?: false
                        val customDestination = call.argument<String>("customDestination")
                        scope.launch {
                            try {
                                val outcome = mediaActionHandler.moveOrCopyItems(
                                    rawItems, isMove, isArchive, customDestination
                                )
                                result.success(outcome)
                            } catch (e: Exception) {
                                result.error("ACTION_FAILED", e.message, null)
                            }
                        }
                    }
                    "queryTrashedItems" -> {
                        scope.launch {
                            try {
                                val trashed = mediaActionHandler.queryTrashedItems()
                                result.success(trashed)
                            } catch (e: Exception) {
                                result.error("QUERY_TRASH_FAILED", e.message, null)
                            }
                        }
                    }
                    "openMedia" -> {
                        val uri = call.argument<String>("uri") ?: ""
                        val mime = call.argument<String>("mimeType") ?: "*/*"
                        mediaActionHandler.openMedia(uri, mime, result)
                    }
                    else -> result.notImplemented()
                }
            }

        // --- MethodChannel: perceptual hash engine (REQ-SIM-01) ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIMILAR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "computeBatchHashes" -> {
                        val uris = call.argument<List<String>>("uris") ?: emptyList()
                        scope.launch {
                            try {
                                val hashes = perceptualHashEngine.computeBatchHashes(uris)
                                result.success(hashes)
                            } catch (e: Exception) {
                                result.error("HASH_FAILED", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // --- MethodChannel: blur detector engine (REQ-BLR-01) ---
        blurDetectorEngine = BlurDetectorEngine(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLUR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "computeBatchBlurScores" -> {
                        val uris = call.argument<List<String>>("uris") ?: emptyList()
                        scope.launch {
                            try {
                                val scores = blurDetectorEngine.computeBatchBlur(uris)
                                result.success(scores)
                            } catch (e: Exception) {
                                result.error("BLUR_FAILED", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // --- MethodChannel & EventChannel: video compressor (REQ-ACT-09, REQ-CMP-01..04) ---
        videoCompressorEngine = VideoCompressorEngine(applicationContext)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, COMPRESSOR_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    compressorEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    compressorEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COMPRESSOR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "compressVideo" -> {
                        val uriStr = call.argument<String>("uri") ?: ""
                        val targetHeight = (call.argument<Number>("targetHeight") ?: 720).toInt()
                        val targetBitrate = (call.argument<Number>("targetBitrateBps") ?: 2500000).toInt()

                        scope.launch {
                            val res = videoCompressorEngine.compressVideo(
                                uriStr = uriStr,
                                targetHeight = targetHeight,
                                targetBitrateBps = targetBitrate,
                                onProgress = { progress ->
                                    scope.launch(Dispatchers.Main) {
                                        compressorEventSink?.success(
                                            mapOf(
                                                "progress" to progress,
                                                "step" to "transcoding"
                                            )
                                        )
                                    }
                                }
                            )

                            if (res.isSuccess) {
                                result.success(res.getOrNull())
                            } else {
                                val error = res.exceptionOrNull()?.message ?: "Compression failed"
                                result.error("COMPRESSION_FAILED", error, null)
                            }
                        }
                    }
                    "cancelCompression" -> {
                        videoCompressorEngine.cancel()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // --- Notification channels initialization ---
        NotificationHelper.createNotificationChannels(applicationContext)

        // --- MethodChannel: WorkManager background tasks (REQ-SET-04, P-02) ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleScan" -> {
                        val intervalHours = (call.argument<Number>("intervalHours") ?: 24).toLong()
                        val chargingOnly  = call.argument<Boolean>("chargingOnly") ?: true

                        val constraints = Constraints.Builder()
                            .setRequiresCharging(chargingOnly)
                            .setRequiresBatteryNotLow(true)
                            .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                            .build()

                        val request = PeriodicWorkRequestBuilder<BackgroundScanWorker>(
                            intervalHours, TimeUnit.HOURS
                        )
                            .setConstraints(constraints)
                            .addTag(BackgroundScanWorker.WORK_TAG)
                            .build()

                        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
                            BackgroundScanWorker.WORK_TAG,
                            ExistingPeriodicWorkPolicy.UPDATE,
                            request
                        )
                        result.success(null)
                    }
                    "cancelScan" -> {
                        WorkManager.getInstance(applicationContext)
                            .cancelUniqueWork(BackgroundScanWorker.WORK_TAG)
                        result.success(null)
                    }
                    "isScheduled" -> {
                        scope.launch(Dispatchers.IO) {
                            val workInfos = WorkManager.getInstance(applicationContext)
                                .getWorkInfosForUniqueWork(BackgroundScanWorker.WORK_TAG)
                                .get()
                            val isScheduled = workInfos.any {
                                !it.state.isFinished
                            }
                            scope.launch(Dispatchers.Main) {
                                result.success(isScheduled)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // --- MethodChannel: Notifications (REQ-SET-05) ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission", "hasPermission" -> {
                        val enabled = NotificationManagerCompat.from(applicationContext).areNotificationsEnabled()
                        result.success(enabled)
                    }
                    "showNotification" -> {
                        val id = (call.argument<Number>("id") ?: 1).toInt()
                        val channelId = call.argument<String>("channelId") ?: NotificationHelper.CHANNEL_STORAGE_ALERTS
                        val title = call.argument<String>("title") ?: "WappTidy"
                        val body = call.argument<String>("body") ?: ""
                        val posted = NotificationHelper.showNotification(
                            applicationContext,
                            id,
                            channelId,
                            title,
                            body
                        )
                        result.success(posted)
                    }
                    "cancelAll" -> {
                        NotificationManagerCompat.from(applicationContext).cancelAll()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        mediaActionHandler.handleActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        mediaIndexer.dispose()
    }
}
