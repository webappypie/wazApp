package com.wapptidy.wapptidy

/*
 * MainActivity.kt
 *
 * Registers two platform channels:
 *   - com.wapptidy/media_indexer        (MethodChannel)  — control: start/pause/cancel/generation
 *   - com.wapptidy/media_indexer_events (EventChannel)   — streaming progress updates
 *
 * PRD §5.4: All heavy MediaStore work happens in Kotlin (MediaIndexer.kt),
 * not in Dart isolates.
 */

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL   = "com.wapptidy/media_indexer"
        private const val EVENT_CHANNEL    = "com.wapptidy/media_indexer_events"
    }

    private lateinit var mediaIndexer: MediaIndexer

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaIndexer = MediaIndexer(applicationContext)

        // --- MethodChannel: control commands ---
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

        // --- EventChannel: progress stream ---
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    mediaIndexer.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    mediaIndexer.eventSink = null
                }
            })
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaIndexer.dispose()
    }
}
