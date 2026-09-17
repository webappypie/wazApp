package com.wapptidy.wapptidy

/*
 * BlurDetectorEngine.kt
 *
 * Implements multi-scale discrete Laplacian variance blur detection on downsampled
 * thumbnails (REQ-BLR-01, PRD §5.4).
 *
 * CRITICAL RULES:
 *   - REQ-BLR-01: Two confidence tiers: "Very blurry" and "Possibly blurry".
 *   - Shallow depth of field (DoF) and intentional bokeh must NOT be flagged as blurry.
 *   - Operates strictly on decoded thumbnails (inSampleSize = 8), never full-resolution decodes.
 *   - RenderScript-free bitmap ops for high performance on Android 10-15.
 */

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.max

data class BlurResult(
    val globalVariance: Double,
    val maxBlockVariance: Double,
    val confidence: String, // "very_blurry", "possibly_blurry", "sharp"
    val isShallowDoF: Boolean
)

class BlurDetectorEngine(private val context: Context) {

    companion object {
        const val TARGET_SIZE = 128
        const val VERY_BLURRY_THRESHOLD = 100.0
        const val POSSIBLY_BLURRY_THRESHOLD = 250.0
        const val SHALLOW_DOF_SHARP_THRESHOLD = 500.0
    }

    /**
     * Compute blur metrics for a batch of media URIs.
     * Returns Map of UriString -> Map<String, Any> (variance, confidence, isShallowDoF).
     */
    suspend fun computeBatchBlur(uris: List<String>): Map<String, Map<String, Any>> = withContext(Dispatchers.IO) {
        val results = mutableMapOf<String, Map<String, Any>>()

        for (uriStr in uris) {
            try {
                val result = computeBlur(Uri.parse(uriStr))
                if (result != null) {
                    results[uriStr] = mapOf(
                        "globalVariance" to result.globalVariance,
                        "maxBlockVariance" to result.maxBlockVariance,
                        "confidence" to result.confidence,
                        "isShallowDoF" to result.isShallowDoF
                    )
                }
            } catch (_: Exception) {
                // Ignore failure for unreadable or corrupt images
            }
        }

        results
    }

    fun computeBlur(uri: Uri): BlurResult? {
        // 1. Decode thumbnail only with inSampleSize = 8 (REQ-BLR-01 / PRD §5.4)
        val opts = BitmapFactory.Options().apply {
            inSampleSize = 8
            inPreferredConfig = Bitmap.Config.RGB_565
        }

        val stream = context.contentResolver.openInputStream(uri) ?: return null
        val sourceBitmap = stream.use { BitmapFactory.decodeStream(it, null, opts) } ?: return null

        // 2. Rescale to standardized 128x128 for normalized Laplacian variance
        val scaled = Bitmap.createScaledBitmap(sourceBitmap, TARGET_SIZE, TARGET_SIZE, true)
        if (sourceBitmap != scaled) {
            sourceBitmap.recycle()
        }

        val width = scaled.width
        val height = scaled.height

        // 3. Extract grayscale pixels
        val gray = IntArray(width * height)
        for (y in 0 until height) {
            for (x in 0 until width) {
                val pixel = scaled.getPixel(x, y)
                val r = Color.red(pixel)
                val g = Color.green(pixel)
                val b = Color.blue(pixel)
                gray[y * width + x] = (r * 299 + g * 587 + b * 114) / 1000
            }
        }
        scaled.recycle()

        // 4. Compute discrete 3x3 Laplacian response:
        // [ 0  1  0 ]
        // [ 1 -4  1 ]
        // [ 0  1  0 ]
        val lapWidth = width - 2
        val lapHeight = height - 2
        val laplacian = DoubleArray(lapWidth * lapHeight)

        var sum = 0.0
        var idx = 0
        for (y in 1 until height - 1) {
            for (x in 1 until width - 1) {
                val center = gray[y * width + x]
                val top = gray[(y - 1) * width + x]
                val bottom = gray[(y + 1) * width + x]
                val left = gray[y * width + (x - 1)]
                val right = gray[y * width + (x + 1)]

                val lVal = (top + bottom + left + right - 4 * center).toDouble()
                laplacian[idx] = lVal
                sum += lVal
                idx++
            }
        }

        val totalPixels = laplacian.size
        val mean = sum / totalPixels

        var varSum = 0.0
        for (v in laplacian) {
            val diff = v - mean
            varSum += diff * diff
        }
        val globalVariance = varSum / totalPixels

        // 5. Regional grid analysis (3x3 grid) for Shallow Depth-of-Field (bokeh)
        val blockW = lapWidth / 3
        val blockH = lapHeight / 3
        var maxBlockVariance = 0.0

        for (by in 0 until 3) {
            for (bx in 0 until 3) {
                var bSum = 0.0
                val bStartX = bx * blockW
                val bStartY = by * blockH
                val count = blockW * blockH

                for (y in 0 until blockH) {
                    for (x in 0 until blockW) {
                        val v = laplacian[(bStartY + y) * lapWidth + (bStartX + x)]
                        bSum += v
                    }
                }
                val bMean = bSum / count

                var bVarSum = 0.0
                for (y in 0 until blockH) {
                    for (x in 0 until blockW) {
                        val v = laplacian[(bStartY + y) * lapWidth + (bStartX + x)]
                        val d = v - bMean
                        bVarSum += d * d
                    }
                }
                val blockVar = bVarSum / count
                maxBlockVariance = max(maxBlockVariance, blockVar)
            }
        }

        // 6. Classification & Shallow Depth-of-Field Protection (REQ-BLR-01)
        val isShallowDoF = maxBlockVariance >= SHALLOW_DOF_SHARP_THRESHOLD && globalVariance < POSSIBLY_BLURRY_THRESHOLD

        val confidence = when {
            isShallowDoF -> "sharp"
            globalVariance < VERY_BLURRY_THRESHOLD && maxBlockVariance < VERY_BLURRY_THRESHOLD * 1.5 -> "very_blurry"
            globalVariance < POSSIBLY_BLURRY_THRESHOLD && maxBlockVariance < POSSIBLY_BLURRY_THRESHOLD * 1.5 -> "possibly_blurry"
            else -> "sharp"
        }

        return BlurResult(
            globalVariance = globalVariance,
            maxBlockVariance = maxBlockVariance,
            confidence = confidence,
            isShallowDoF = isShallowDoF
        )
    }
}
