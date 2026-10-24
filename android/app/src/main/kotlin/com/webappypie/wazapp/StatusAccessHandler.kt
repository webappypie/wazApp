package com.webappypie.wazapp

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Native bridge for user-authorised WhatsApp status access.
 *
 * Design rules (docs/PLATFORM_COMPATIBILITY.md):
 *  - Only the Storage Access Framework is used: the user picks the status folder and the
 *    grant is persisted with takePersistableUriPermission. No hidden APIs, no root, no
 *    MANAGE_EXTERNAL_STORAGE.
 *  - WhatsApp and WhatsApp Business are validated and stored separately.
 *  - Files are copied to a temp name, size-verified, then renamed; originals are never touched.
 *  - All I/O runs off the main thread.
 */
class StatusAccessHandler(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    companion object {
        const val CHANNEL = "com.webappypie.wazapp/status_access"
        private const val REQUEST_PICK_TREE = 7101
        private const val PREFS = "wazapp_status_access"
        private const val EXTERNAL_STORAGE_AUTHORITY = "com.android.externalstorage.documents"

        private const val PKG_WHATSAPP = "com.whatsapp"
        private const val PKG_BUSINESS = "com.whatsapp.w4b"
        private const val STATUS_DIR = ".Statuses"

        private val IMAGE_EXT = setOf("jpg", "jpeg", "png", "webp", "gif")
        private val VIDEO_EXT = setOf("mp4", "3gp", "mkv", "webm", "mov")
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val io = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())
    private val prefs get() = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private var pendingPick: MethodChannel.Result? = null
    private var pendingApp: String? = null

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "installedApps" -> result.success(
                        mapOf(
                            "whatsapp" to isInstalled(PKG_WHATSAPP),
                            "business" to isInstalled(PKG_BUSINESS),
                        )
                    )
                    "hasAccess" -> {
                        val app = requireApp(call.argument("app"))
                        background(result) { hasAccess(app) }
                    }
                    "requestAccess" -> requestAccess(requireApp(call.argument("app")), result)
                    "revokeAccess" -> {
                        val app = requireApp(call.argument("app"))
                        background(result) {
                            revokeAccess(app)
                            true
                        }
                    }
                    "listStatuses" -> {
                        val app = requireApp(call.argument("app"))
                        background(result) { listStatuses(app) }
                    }
                    "thumbnail" -> {
                        val uri = arg(call.argument<String>("uri"), "uri")
                        val isVideo = call.argument<Boolean>("isVideo") ?: false
                        val size = call.argument<Int>("size") ?: 360
                        background(result) { thumbnail(uri, isVideo, size) }
                    }
                    "copyToFile" -> {
                        val uri = arg(call.argument<String>("uri"), "uri")
                        val dest = arg(call.argument<String>("destPath"), "destPath")
                        val isVideo = call.argument<Boolean>("isVideo") ?: false
                        background(result) { copyToFile(uri, dest, isVideo) }
                    }
                    "describeFile" -> {
                        val path = arg(call.argument<String>("path"), "path")
                        val isVideo = call.argument<Boolean>("isVideo") ?: false
                        background(result) { describeFile(path, isVideo) }
                    }
                    "exportToGallery" -> {
                        val path = arg(call.argument<String>("path"), "path")
                        val mime = call.argument<String>("mimeType") ?: "application/octet-stream"
                        val name = arg(call.argument<String>("displayName"), "displayName")
                        val isVideo = call.argument<Boolean>("isVideo") ?: false
                        background(result) { exportToGallery(path, mime, name, isVideo) }
                    }
                    else -> result.notImplemented()
                }
            } catch (f: Fail) {
                result.error(f.code, f.message, null)
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        io.shutdownNow()
    }

    // ---------------------------------------------------------------------------------------
    // Access
    // ---------------------------------------------------------------------------------------

    private class Fail(val code: String, message: String) : Exception(message)

    private fun arg(value: String?, name: String): String =
        value ?: throw Fail("bad_args", "$name missing")

    private fun requireApp(app: String?): String =
        if (app == "whatsapp" || app == "business") app else throw Fail("bad_args", "unknown app")

    private fun pkgOf(app: String) = if (app == "business") PKG_BUSINESS else PKG_WHATSAPP

    private fun isInstalled(pkg: String): Boolean = try {
        activity.packageManager.getPackageInfo(pkg, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    private fun requestAccess(app: String, result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "Another folder request is in progress", null)
            return
        }
        val pkg = pkgOf(app)
        val hint = if (app == "business") "WhatsApp Business" else "WhatsApp"
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
            // Open the picker directly on the expected status folder (a hint only; the OS may ignore it).
            putExtra(
                DocumentsContract.EXTRA_INITIAL_URI,
                DocumentsContract.buildDocumentUri(
                    EXTERNAL_STORAGE_AUTHORITY,
                    "primary:Android/media/$pkg/$hint/Media/$STATUS_DIR",
                ),
            )
        }
        pendingPick = result
        pendingApp = app
        try {
            activity.startActivityForResult(intent, REQUEST_PICK_TREE)
        } catch (e: Exception) {
            pendingPick = null
            pendingApp = null
            result.error("picker_unavailable", "No folder picker is available on this device", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_TREE) return false
        val result = pendingPick ?: return true
        val app = pendingApp ?: return true
        pendingPick = null
        pendingApp = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(mapOf("status" to "cancelled"))
            return true
        }
        io.execute {
            val outcome: Map<String, Any?> = try {
                val dirId = resolveStatusDir(tree, app)
                    ?: throw Fail("wrong_folder", "No .Statuses folder was found in the chosen folder")
                activity.contentResolver.takePersistableUriPermission(
                    tree, Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
                prefs.edit()
                    .putString("tree_$app", tree.toString())
                    .putString("dir_$app", dirId)
                    .apply()
                mapOf("status" to "granted")
            } catch (f: Fail) {
                mapOf("status" to f.code, "message" to f.message)
            } catch (e: Exception) {
                mapOf("status" to "error", "message" to (e.message ?: "unknown"))
            }
            main.post { result.success(outcome) }
        }
        return true
    }

    private fun hasAccess(app: String): Boolean {
        val tree = prefs.getString("tree_$app", null) ?: return false
        val dir = prefs.getString("dir_$app", null) ?: return false
        val uri = Uri.parse(tree)
        val persisted = activity.contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission
        }
        if (!persisted) return false
        // The folder must still be listable (WhatsApp may have been reinstalled/cleared).
        return try {
            queryChildren(uri, dir)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun revokeAccess(app: String) {
        val tree = prefs.getString("tree_$app", null)
        if (tree != null) {
            try {
                activity.contentResolver.releasePersistableUriPermission(
                    Uri.parse(tree), Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: Exception) {
                // Permission may already be gone; clearing our record is what matters.
            }
        }
        prefs.edit().remove("tree_$app").remove("dir_$app").apply()
    }

    // ---------------------------------------------------------------------------------------
    // Folder resolution / listing
    // ---------------------------------------------------------------------------------------

    private data class Child(
        val docId: String,
        val name: String,
        val mime: String,
        val size: Long,
        val modified: Long,
    )

    private fun isDir(c: Child) = c.mime == DocumentsContract.Document.MIME_TYPE_DIR

    private fun queryChildren(tree: Uri, parentDocId: String): List<Child> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentDocId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        val out = ArrayList<Child>()
        val cursor = activity.contentResolver.query(uri, projection, null, null, null)
            ?: throw Fail("source_unavailable", "Folder cannot be read")
        cursor.use {
            while (it.moveToNext()) {
                out.add(
                    Child(
                        it.getString(0),
                        it.getString(1) ?: "",
                        it.getString(2) ?: "",
                        if (it.isNull(3)) 0L else it.getLong(3),
                        if (it.isNull(4)) 0L else it.getLong(4),
                    )
                )
            }
        }
        return out
    }

    /** Finds the `.Statuses` directory at or below the picked folder (max depth 3). */
    private fun resolveStatusDir(tree: Uri, app: String): String? {
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val found = findStatusDir(tree, rootId, 0) ?: return null
        val lower = found.lowercase()
        val business = lower.contains(PKG_BUSINESS) || lower.contains("whatsapp business")
        val whatsapp = lower.contains("whatsapp")
        // Keep WhatsApp and WhatsApp Business strictly separate.
        return when {
            app == "business" && business -> found
            app == "whatsapp" && whatsapp && !business -> found
            else -> null
        }
    }

    private fun findStatusDir(tree: Uri, docId: String, depth: Int): String? {
        if (docId.substringAfterLast('/') == STATUS_DIR) return docId
        if (depth >= 3) return null
        val children = try {
            queryChildren(tree, docId)
        } catch (_: Exception) {
            return null
        }
        for (c in children) {
            if (isDir(c) && c.name == STATUS_DIR) return c.docId
        }
        for (c in children) {
            if (isDir(c)) findStatusDir(tree, c.docId, depth + 1)?.let { return it }
        }
        return null
    }

    private fun kindOf(c: Child): String? {
        val ext = c.name.substringAfterLast('.', "").lowercase()
        return when {
            c.mime.startsWith("image/") || ext in IMAGE_EXT -> "image"
            c.mime.startsWith("video/") || ext in VIDEO_EXT -> "video"
            else -> null
        }
    }

    private fun listStatuses(app: String): List<Map<String, Any?>> {
        val tree = prefs.getString("tree_$app", null)?.let(Uri::parse)
            ?: throw Fail("no_access", "Status folder has not been selected")
        val dir = prefs.getString("dir_$app", null)
            ?: throw Fail("no_access", "Status folder has not been selected")
        val children = try {
            queryChildren(tree, dir)
        } catch (e: SecurityException) {
            throw Fail("no_access", "Access to the status folder was revoked")
        }
        return children.mapNotNull { c ->
            if (isDir(c)) return@mapNotNull null
            val kind = kindOf(c) ?: return@mapNotNull null
            val mime = if (c.mime.isNotEmpty() && c.mime != "application/octet-stream") c.mime
            else if (kind == "video") "video/mp4" else "image/jpeg"
            mapOf(
                "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, c.docId).toString(),
                "name" to c.name,
                "kind" to kind,
                "mimeType" to mime,
                "size" to c.size,
                "modifiedMs" to c.modified,
            )
        }.sortedByDescending { it["modifiedMs"] as Long }
    }

    // ---------------------------------------------------------------------------------------
    // Thumbnails / copy / metadata
    // ---------------------------------------------------------------------------------------

    private fun thumbnail(uriStr: String, isVideo: Boolean, size: Int): ByteArray? {
        val uri = parseUri(uriStr)
        val bitmap: Bitmap = (if (isVideo) videoFrame(uri, size) else imageThumb(uri, size)) ?: return null
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
        bitmap.recycle()
        return out.toByteArray()
    }

    private fun parseUri(s: String): Uri = if (s.startsWith("/")) Uri.fromFile(File(s)) else Uri.parse(s)

    private fun imageThumb(uri: Uri, target: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        activity.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= target && bounds.outHeight / (sample * 2) >= target) sample *= 2
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        val decoded = activity.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, opts)
        } ?: return null
        val rotation = try {
            activity.contentResolver.openInputStream(uri)?.use { s ->
                when (ExifInterface(s).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                    else -> 0f
                }
            } ?: 0f
        } catch (_: Exception) {
            0f
        }
        if (rotation == 0f) return decoded
        val rotated = Bitmap.createBitmap(
            decoded, 0, 0, decoded.width, decoded.height, Matrix().apply { postRotate(rotation) }, true,
        )
        if (rotated != decoded) decoded.recycle()
        return rotated
    }

    private fun videoFrame(uri: Uri, target: Int): Bitmap? {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(activity, uri)
            val frame = r.getFrameAtTime(1_000_000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                ?: r.getFrameAtTime(0) ?: return null
            val scale = target.toFloat() / maxOf(frame.width, frame.height)
            if (scale >= 1f) return frame
            val scaled = Bitmap.createScaledBitmap(
                frame,
                (frame.width * scale).toInt().coerceAtLeast(1),
                (frame.height * scale).toInt().coerceAtLeast(1),
                true,
            )
            if (scaled != frame) frame.recycle()
            return scaled
        } finally {
            r.release()
        }
    }

    private fun copyToFile(uriStr: String, destPath: String, isVideo: Boolean): Map<String, Any?> {
        val uri = parseUri(uriStr)
        val dest = File(destPath)
        val tmp = File("$destPath.part")
        dest.parentFile?.mkdirs()
        val expected = try {
            activity.contentResolver.openAssetFileDescriptor(uri, "r")?.use { it.length } ?: -1L
        } catch (_: Exception) {
            throw Fail("source_unavailable", "The status is no longer available")
        }
        if (expected > 0 && (dest.parentFile?.usableSpace ?: Long.MAX_VALUE) < expected + 1_048_576) {
            throw Fail("low_storage", "Not enough free storage to save this item")
        }
        try {
            var written = 0L
            val input = activity.contentResolver.openInputStream(uri)
                ?: throw Fail("source_unavailable", "The status is no longer available")
            input.use { src ->
                tmp.outputStream().use { dst ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = src.read(buf)
                        if (n < 0) break
                        dst.write(buf, 0, n)
                        written += n
                    }
                    dst.fd.sync()
                }
            }
            if (written <= 0L || (expected > 0 && written != expected) || tmp.length() != written) {
                throw Fail("verify_failed", "Copied file did not match the original")
            }
            if (dest.exists()) dest.delete()
            if (!tmp.renameTo(dest)) throw Fail("copy_failed", "Could not finalise the saved file")
        } catch (f: Fail) {
            tmp.delete()
            throw f
        } catch (e: IOException) {
            tmp.delete()
            val low = e.message?.contains("ENOSPC") == true
            throw Fail(if (low) "low_storage" else "copy_failed", e.message ?: "copy failed")
        } catch (e: SecurityException) {
            tmp.delete()
            throw Fail("no_access", "Access to the status folder was revoked")
        }
        return try {
            describeFile(dest.absolutePath, isVideo)
        } catch (f: Fail) {
            // A copy that cannot be decoded must not enter the library.
            dest.delete()
            throw f
        }
    }

    private fun describeFile(path: String, isVideo: Boolean): Map<String, Any?> {
        val file = File(path)
        if (!file.exists() || file.length() <= 0L) throw Fail("missing", "File not found")
        var width: Int
        var height: Int
        var durationMs = 0L
        if (isVideo) {
            val r = MediaMetadataRetriever()
            try {
                r.setDataSource(path)
                width = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
                height = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
                durationMs = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
                if (rot == 90 || rot == 270) {
                    val t = width
                    width = height
                    height = t
                }
            } catch (_: Exception) {
                throw Fail("corrupt", "The video file is not readable")
            } finally {
                r.release()
            }
            if (durationMs <= 0L || width <= 0) throw Fail("corrupt", "The video file is not readable")
        } else {
            val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, o)
            width = o.outWidth
            height = o.outHeight
            if (width <= 0 || height <= 0) throw Fail("corrupt", "The image file is not readable")
        }
        return mapOf("width" to width, "height" to height, "durationMs" to durationMs, "size" to file.length())
    }

    // ---------------------------------------------------------------------------------------
    // Gallery export (explicit user action)
    // ---------------------------------------------------------------------------------------

    private fun exportToGallery(path: String, mime: String, displayName: String, isVideo: Boolean): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw Fail("unsupported_os", "Saving to the gallery needs Android 10 or newer. Use Share instead.")
        }
        val src = File(path)
        if (!src.exists()) throw Fail("missing", "File not found")
        val collection = if (isVideo) MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        else MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val folder = if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, "$folder/WazApp")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = activity.contentResolver
        val target = resolver.insert(collection, values)
            ?: throw Fail("export_failed", "Could not create gallery entry")
        try {
            resolver.openOutputStream(target)?.use { out -> src.inputStream().use { it.copyTo(out) } }
                ?: throw Fail("export_failed", "Could not open gallery entry")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(target, values, null, null)
        } catch (e: Exception) {
            resolver.delete(target, null, null)
            if (e is Fail) throw e
            throw Fail("export_failed", e.message ?: "export failed")
        }
        return target.toString()
    }

    // ---------------------------------------------------------------------------------------

    private fun <T> background(result: MethodChannel.Result, block: () -> T) {
        io.execute {
            try {
                val v = block()
                main.post { result.success(v) }
            } catch (f: Fail) {
                main.post { result.error(f.code, f.message, null) }
            } catch (e: Exception) {
                main.post { result.error("error", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }
}
