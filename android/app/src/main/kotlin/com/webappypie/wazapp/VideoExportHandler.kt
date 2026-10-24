package com.webappypie.wazapp

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.Crop
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import com.google.common.collect.ImmutableList
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Real H.264/AAC export of an edited video with Media3 Transformer.
 *
 * Supported edits (and nothing else is offered by the app):
 *  - trim (start/end, re-encoded so cuts are frame accurate)
 *  - mute (audio track removed)
 *  - crop (normalised rectangle of the upright frame)
 *  - one full-frame transparent overlay bitmap (text/stickers are rendered by Dart so Hindi shaping
 *    and fonts match the on-screen preview exactly)
 *  - output size (even width/height; optionally scaled down)
 *
 * The source is only read. Output goes to the path given by Dart (a temp file); Dart verifies it
 * before it enters the library. Cancelling deletes the partial output.
 */
class VideoExportHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    companion object {
        const val CHANNEL = "com.webappypie.wazapp/video_export"
        private const val PROGRESS_INTERVAL_MS = 250L
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()

    private var transformer: Transformer? = null
    private var pendingResult: MethodChannel.Result? = null
    private var activeId: String? = null
    private var activeOutput: File? = null
    private var cancelled = false
    private var progressRunnable: Runnable? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "export" -> startExport(call.arguments as? Map<*, *>, result)
                "cancel" -> {
                    cancelActive()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        cancelActive()
        io.shutdownNow()
    }

    private fun fail(result: MethodChannel.Result, code: String, message: String) =
        result.error(code, message, null)

    private fun startExport(args: Map<*, *>?, result: MethodChannel.Result) {
        if (args == null) return fail(result, "bad_args", "arguments missing")
        if (pendingResult != null) return fail(result, "busy", "Another export is already running")

        val id = args["id"] as? String ?: return fail(result, "bad_args", "id missing")
        val input = args["inputPath"] as? String ?: return fail(result, "bad_args", "inputPath missing")
        val output = args["outputPath"] as? String ?: return fail(result, "bad_args", "outputPath missing")
        val startMs = (args["startMs"] as? Number)?.toLong() ?: 0L
        val endMs = (args["endMs"] as? Number)?.toLong() ?: return fail(result, "bad_args", "endMs missing")
        val mute = args["mute"] as? Boolean ?: false
        val outW = (args["outWidth"] as? Number)?.toInt() ?: return fail(result, "bad_args", "outWidth missing")
        val outH = (args["outHeight"] as? Number)?.toInt() ?: return fail(result, "bad_args", "outHeight missing")
        val overlayPath = args["overlayPngPath"] as? String
        val crop = args["crop"] as? Map<*, *>
        val bitrate = (args["videoBitrate"] as? Number)?.toInt() ?: 0

        val inFile = File(input)
        if (!inFile.exists() || inFile.length() <= 0L) {
            return fail(result, "source_unavailable", "The source video is not available")
        }
        if (endMs <= startMs || outW < 2 || outH < 2 || outW % 2 != 0 || outH % 2 != 0) {
            return fail(result, "bad_args", "invalid trim or output size")
        }
        val outFile = File(output)
        outFile.parentFile?.mkdirs()
        if (outFile.exists()) outFile.delete()

        // Rough output size estimate (bitrate * duration) with headroom, to fail early on a full disk.
        val estimateBytes = ((endMs - startMs) / 1000.0 * (if (bitrate > 0) bitrate else 8_000_000) / 8.0 * 1.2).toLong()
        val usable = outFile.parentFile?.usableSpace ?: Long.MAX_VALUE
        if (usable < estimateBytes + 16L * 1024 * 1024) {
            return fail(result, "low_storage", "Not enough free storage to export this video")
        }

        pendingResult = result
        activeId = id
        activeOutput = outFile
        cancelled = false

        // Decode the overlay bitmap off the main thread, then start on the main (Looper) thread.
        io.execute {
            val overlay: Bitmap? = try {
                overlayPath?.let { BitmapFactory.decodeFile(it) }
            } catch (e: Throwable) {
                null
            }
            if (overlayPath != null && overlay == null) {
                main.post { finishError("overlay_failed", "The text/sticker layer could not be prepared") }
                return@execute
            }
            main.post {
                if (cancelled) return@post
                try {
                    begin(inFile, outFile, startMs, endMs, mute, crop, outW, outH, overlay, bitrate)
                } catch (e: Throwable) {
                    finishError("export_failed", e.message ?: e.javaClass.simpleName)
                }
            }
        }
    }

    private fun begin(
        input: File,
        output: File,
        startMs: Long,
        endMs: Long,
        mute: Boolean,
        crop: Map<*, *>?,
        outW: Int,
        outH: Int,
        overlay: Bitmap?,
        bitrate: Int,
    ) {
        val mediaItem = MediaItem.Builder()
            .setUri(Uri.fromFile(input))
            .setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(startMs)
                    .setEndPositionMs(endMs)
                    .build()
            )
            .build()

        val effects = ArrayList<Effect>()
        if (crop != null) {
            val l = (crop["left"] as Number).toFloat()
            val t = (crop["top"] as Number).toFloat()
            val r = (crop["right"] as Number).toFloat()
            val b = (crop["bottom"] as Number).toFloat()
            // Dart gives a top-left origin rectangle in 0..1; Media3 wants NDC (-1..1, y up).
            effects.add(Crop(l * 2f - 1f, r * 2f - 1f, 1f - b * 2f, 1f - t * 2f))
        }
        effects.add(Presentation.createForWidthAndHeight(outW, outH, Presentation.LAYOUT_SCALE_TO_FIT))
        if (overlay != null) {
            effects.add(OverlayEffect(ImmutableList.of<TextureOverlay>(BitmapOverlay.createStaticBitmapOverlay(overlay))))
        }

        val edited = EditedMediaItem.Builder(mediaItem)
            .setRemoveAudio(mute)
            .setEffects(Effects(emptyList(), effects))
            .build()

        val builder = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
        if (bitrate > 0) {
            builder.setEncoderFactory(
                DefaultEncoderFactory.Builder(context)
                    .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(bitrate).build())
                    .build()
            )
        }
        val t = builder.addListener(object : Transformer.Listener {
            override fun onCompleted(composition: androidx.media3.transformer.Composition, exportResult: ExportResult) {
                overlay?.recycle()
                finishSuccess(output, exportResult)
            }

            override fun onError(
                composition: androidx.media3.transformer.Composition,
                exportResult: ExportResult,
                exportException: ExportException,
            ) {
                overlay?.recycle()
                if (cancelled) return
                val unsupported = exportException.errorCode == ExportException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED ||
                    exportException.errorCode == ExportException.ERROR_CODE_ENCODING_FORMAT_UNSUPPORTED ||
                    exportException.errorCode == ExportException.ERROR_CODE_DECODER_INIT_FAILED ||
                    exportException.errorCode == ExportException.ERROR_CODE_ENCODER_INIT_FAILED
                finishError(
                    if (unsupported) "unsupported" else "export_failed",
                    exportException.errorCodeName,
                )
            }
        }).build()
        transformer = t
        t.start(edited, output.absolutePath)
        scheduleProgress()
    }

    private fun scheduleProgress() {
        val holder = ProgressHolder()
        val r = object : Runnable {
            override fun run() {
                val t = transformer ?: return
                val state = t.getProgress(holder)
                if (state == Transformer.PROGRESS_STATE_AVAILABLE) {
                    channel.invokeMethod(
                        "progress",
                        mapOf("id" to activeId, "progress" to holder.progress / 100.0),
                    )
                }
                if (transformer != null) main.postDelayed(this, PROGRESS_INTERVAL_MS)
            }
        }
        progressRunnable = r
        main.postDelayed(r, PROGRESS_INTERVAL_MS)
    }

    private fun clearActive() {
        progressRunnable?.let { main.removeCallbacks(it) }
        progressRunnable = null
        transformer = null
        pendingResult = null
        activeId = null
        activeOutput = null
    }

    private fun finishSuccess(output: File, r: ExportResult) {
        val result = pendingResult
        clearActive()
        result?.success(
            mapOf(
                "outputPath" to output.absolutePath,
                "durationMs" to r.approximateDurationMs,
                "width" to r.width,
                "height" to r.height,
                "fileSize" to r.fileSizeBytes,
            )
        )
    }

    private fun finishError(code: String, message: String) {
        val result = pendingResult
        val out = activeOutput
        clearActive()
        out?.delete()
        result?.error(code, message, null)
    }

    private fun cancelActive() {
        val result = pendingResult ?: return
        cancelled = true
        val out = activeOutput
        try {
            transformer?.cancel()
        } catch (_: Throwable) {
            // already finished
        }
        clearActive()
        out?.delete()
        result.error("cancelled", "Export cancelled", null)
    }
}
