package com.wapptidy.wapptidy

/*
 * DuplicateDetector.kt
 *
 * Implements two-stage exact duplicate detection in native Kotlin (PRD §5.4, REQ-DUP-01):
 *   Stage 1: Size bucketing (only files with colliding sizes are processed)
 *   Stage 2a: Partial hash (first 64 KB + last 64 KB)
 *   Stage 2b: Full SHA-256 hash only when partial hashes collide
 *
 * Performance budget (PRD §5.5):
 *   Exact-hash pass for 15,000 files < 3 minutes.
 *   Size bucketing filters out >90% of files without reading any disk bytes.
 *
 * Identifies the oldest file as the "Original" per group (REQ-DUP-02).
 * Skips unreadable or deleted files safely without aborting the batch.
 */

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.InputStream
import java.security.MessageDigest

data class CandidateItem(
    val id: String,
    val contentUri: String,
    val displayName: String,
    val mimeType: String,
    val sizeBytes: Long,
    val dateAddedSec: Long,
    val dateModifiedSec: Long,
    val bucketName: String,
    val sourceApp: String,
    val width: Int = 0,
    val height: Int = 0,
    val durationMs: Int = 0,
    val isProtected: Boolean = false
)

class DuplicateDetector(private val context: Context) {

    companion object {
        private const val PARTIAL_CHUNK_SIZE = 64 * 1024 // 64 KB
    }

    suspend fun findDuplicates(items: List<CandidateItem>): List<Map<String, Any>> =
        withContext(Dispatchers.IO) {
            // Stage 1: Size bucketing — ignore any file whose size is unique
            val sizeBuckets = items.groupBy { it.sizeBytes }
                .filter { it.key > 0 && it.value.size > 1 }

            if (sizeBuckets.isEmpty()) return@withContext emptyList()

            val duplicateGroups = mutableListOf<Map<String, Any>>()

            for ((fileSize, candidatesInBucket) in sizeBuckets) {
                // Stage 2a: Partial hash (first 64KB + last 64KB)
                val partialHashBuckets = mutableMapOf<String, MutableList<CandidateItem>>()

                for (candidate in candidatesInBucket) {
                    val partialHash = computePartialHash(candidate.contentUri, fileSize) ?: continue
                    partialHashBuckets.getOrPut(partialHash) { mutableListOf() }.add(candidate)
                }

                // Filter to colliding partial hashes
                val partialCollisions = partialHashBuckets.filter { it.value.size > 1 }

                for ((_, candidatesWithSamePartial) in partialCollisions) {
                    // Stage 2b: Full SHA-256 hash only on partial collision
                    val fullHashBuckets = mutableMapOf<String, MutableList<CandidateItem>>()

                    for (candidate in candidatesWithSamePartial) {
                        val fullHash = computeFullHash(candidate.contentUri) ?: continue
                        fullHashBuckets.getOrPut(fullHash) { mutableListOf() }.add(candidate)
                    }

                    // Duplicate groups: exact match on full hash
                    for ((fullHash, groupItems) in fullHashBuckets) {
                        if (groupItems.size > 1) {
                            // Sort group: oldest first marked as Original (REQ-DUP-02)
                            val sortedGroup = groupItems.sortedWith(
                                compareBy<CandidateItem> { it.dateAddedSec }
                                    .thenBy { it.dateModifiedSec }
                            )

                            val originalItem = sortedGroup.first()
                            val itemsList = sortedGroup.map { item ->
                                val isOriginal = item.id == originalItem.id
                                mapOf(
                                    "id" to item.id,
                                    "contentUri" to item.contentUri,
                                    "displayName" to item.displayName,
                                    "mimeType" to item.mimeType,
                                    "sizeBytes" to item.sizeBytes,
                                    "dateAddedSec" to item.dateAddedSec,
                                    "dateModifiedSec" to item.dateModifiedSec,
                                    "bucketName" to item.bucketName,
                                    "sourceApp" to item.sourceApp,
                                    "width" to item.width,
                                    "height" to item.height,
                                    "durationMs" to item.durationMs,
                                    "isProtected" to item.isProtected,
                                    "isOriginal" to isOriginal,
                                    "badgeLabel" to if (isOriginal) "Original" else "Duplicate"
                                )
                            }

                            val copyCount = groupItems.size
                            val totalGroupBytes = fileSize * copyCount
                            val potentialSaving = fileSize * (copyCount - 1)

                            duplicateGroups.add(
                                mapOf(
                                    "hash" to fullHash,
                                    "fileSize" to fileSize,
                                    "copyCount" to copyCount,
                                    "totalGroupBytes" to totalGroupBytes,
                                    "potentialSaving" to potentialSaving,
                                    "items" to itemsList
                                )
                            )
                        }
                    }
                }
            }

            duplicateGroups
        }

    private fun computePartialHash(contentUriString: String, fileSize: Long): String? {
        return try {
            val uri = Uri.parse(contentUriString)
            val digest = MessageDigest.getInstance("SHA-256")

            context.contentResolver.openInputStream(uri)?.use { stream ->
                if (fileSize <= PARTIAL_CHUNK_SIZE * 2) {
                    // Small file: read all
                    val buffer = ByteArray(PARTIAL_CHUNK_SIZE)
                    var bytesRead: Int
                    while (stream.read(buffer).also { bytesRead = it } != -1) {
                        digest.update(buffer, 0, bytesRead)
                    }
                } else {
                    // Read first 64 KB
                    val firstChunk = ByteArray(PARTIAL_CHUNK_SIZE)
                    var readSoFar = 0
                    while (readSoFar < PARTIAL_CHUNK_SIZE) {
                        val count = stream.read(firstChunk, readSoFar, PARTIAL_CHUNK_SIZE - readSoFar)
                        if (count == -1) break
                        readSoFar += count
                    }
                    digest.update(firstChunk, 0, readSoFar)

                    // Skip to last 64 KB
                    val bytesToSkip = fileSize - PARTIAL_CHUNK_SIZE - readSoFar
                    if (bytesToSkip > 0) {
                        var skipped = 0L
                        while (skipped < bytesToSkip) {
                            val count = stream.skip(bytesToSkip - skipped)
                            if (count <= 0) break
                            skipped += count
                        }
                    }

                    // Read last 64 KB
                    val lastChunk = ByteArray(PARTIAL_CHUNK_SIZE)
                    readSoFar = 0
                    while (readSoFar < PARTIAL_CHUNK_SIZE) {
                        val count = stream.read(lastChunk, readSoFar, PARTIAL_CHUNK_SIZE - readSoFar)
                        if (count == -1) break
                        readSoFar += count
                    }
                    digest.update(lastChunk, 0, readSoFar)
                }

                bytesToHex(digest.digest())
            }
        } catch (e: Exception) {
            // File might have been deleted or permission lost; skip gracefully
            null
        }
    }

    private fun computeFullHash(contentUriString: String): String? {
        return try {
            val uri = Uri.parse(contentUriString)
            val digest = MessageDigest.getInstance("SHA-256")
            val buffer = ByteArray(16 * 1024)

            context.contentResolver.openInputStream(uri)?.use { stream ->
                var bytesRead: Int
                while (stream.read(buffer).also { bytesRead = it } != -1) {
                    digest.update(buffer, 0, bytesRead)
                }
                bytesToHex(digest.digest())
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun bytesToHex(bytes: ByteArray): String {
        val hexChars = "0123456789abcdef"
        val result = StringBuilder(bytes.size * 2)
        for (b in bytes) {
            val i = b.toInt()
            result.append(hexChars[(i shr 4) and 0x0f])
            result.append(hexChars[i and 0x0f])
        }
        return result.toString()
    }
}
