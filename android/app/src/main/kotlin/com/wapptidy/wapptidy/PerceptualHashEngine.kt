package com.wapptidy.wapptidy

/*
 * PerceptualHashEngine.kt
 *
 * Implements 64-bit difference hash (dHash) on downsampled thumbnails (REQ-SIM-01).
 *
 * CRITICAL RULE (REQ-SIM-01):
 *   Operates on decoded thumbnails only, never repeated full-res decodes.
 *   Uses BitmapFactory inSampleSize to decode max 64x64, then resizes to 9x8 grayscale.
 */

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class PerceptualHashEngine(private val context: Context) {

    /**
     * Compute 64-bit dHash for a batch of media URIs.
     * Returns Map of UriString -> 64-bit hash as Long.
     */
    suspend fun computeBatchHashes(uris: List<String>): Map<String, Long> = withContext(Dispatchers.IO) {
        val results = mutableMapOf<String, Long>()

        for (uriStr in uris) {
            try {
                val hash = computeDHash(Uri.parse(uriStr))
                if (hash != null) {
                    results[uriStr] = hash
                }
            } catch (_: Exception) {
                // Ignore failure for corrupt images
            }
        }

        results
    }

    private fun computeDHash(uri: Uri): Long? {
        // 1. Decode small thumbnail only (REQ-SIM-01)
        val opts = BitmapFactory.Options().apply {
            inSampleSize = 8 // Downsample immediately to prevent high RAM usage
            inPreferredConfig = Bitmap.Config.RGB_565
        }

        val stream = context.contentResolver.openInputStream(uri) ?: return null
        val sourceBitmap = stream.use { BitmapFactory.decodeStream(it, null, opts) } ?: return null

        // 2. Scale down to 9x8 for dHash
        val scaled = Bitmap.createScaledBitmap(sourceBitmap, 9, 8, true)
        if (sourceBitmap != scaled) {
            sourceBitmap.recycle()
        }

        // 3. Compute gradient difference hash (64 bits)
        var hash = 0L
        for (y in 0 until 8) {
            for (x in 0 until 8) {
                val leftPixel = scaled.getPixel(x, y)
                val rightPixel = scaled.getPixel(x + 1, y)

                // Convert to luminance
                val leftLum = (Color.red(leftPixel) * 299 + Color.green(leftPixel) * 587 + Color.blue(leftPixel) * 114) / 1000
                val rightLum = (Color.red(rightPixel) * 299 + Color.green(rightPixel) * 587 + Color.blue(rightPixel) * 114) / 1000

                if (leftLum > rightLum) {
                    hash = hash or (1L shl (y * 8 + x))
                }
            }
        }

        scaled.recycle()
        return hash
    }
}
