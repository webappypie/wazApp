package com.webappypie.wazapp

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Hosts the Flutter UI and wires the native status-access bridge.
 * Channel logic lives in [StatusAccessHandler] and [VideoExportHandler].
 */
class MainActivity : FlutterActivity() {

    private var statusAccess: StatusAccessHandler? = null
    private var videoExport: VideoExportHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        statusAccess = StatusAccessHandler(this, flutterEngine.dartExecutor.binaryMessenger)
        videoExport = VideoExportHandler(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (statusAccess?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        statusAccess?.dispose()
        statusAccess = null
        videoExport?.dispose()
        videoExport = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
