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

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL    = "com.wapptidy/media_indexer"
        private const val EVENT_CHANNEL     = "com.wapptidy/media_indexer_events"
        private const val DUPLICATE_CHANNEL = "com.wapptidy/duplicate_detector"
    }

    private lateinit var mediaIndexer: MediaIndexer
    private lateinit var duplicateDetector: DuplicateDetector
    private val scope = CoroutineScope(Dispatchers.Main)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaIndexer = MediaIndexer(applicationContext)
        duplicateDetector = DuplicateDetector(applicationContext)

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
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        mediaIndexer.dispose()
    }
}
