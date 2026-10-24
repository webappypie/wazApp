// lib/features/video_editor/data/video_export_service.dart
//
// Orchestrates a video export:
//   plan -> overlay layer (PNG) -> native encode -> verify the file -> library.
// The source is only read. Cancellation or any failure removes partial output.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/error/app_error.dart';
import '../../editor/domain/edit_state.dart';
import '../../editor/domain/photo_renderer.dart';
import '../../library/data/library_service.dart';
import '../../library/domain/library_models.dart';
import '../../status/data/status_access_service.dart';
import '../domain/video_edit_state.dart';
import 'video_encoder.dart';

enum VideoExportStage {
  preparing('Preparing'),
  encoding('Encoding'),
  verifying('Checking the result'),
  saving('Saving');

  const VideoExportStage(this.label);
  final String label;
}

class VideoExportService {
  VideoExportService({
    required this.library,
    required this.encoder,
    required this.tools,
    required this.tempDir,
  });

  final LibraryService library;
  final VideoEncoder encoder;
  final MediaTools tools;
  final Directory tempDir;

  bool _cancelRequested = false;

  /// Asks the running export to stop; [exportVideo] then throws [OperationCancelled].
  Future<void> cancel() async {
    _cancelRequested = true;
    await encoder.cancel();
  }

  Future<SavedMedia> exportVideo({
    required SavedMedia source,
    required VideoEditState state,
    required bool sourceHasAudio,
    void Function(VideoExportStage stage)? onStage,
    void Function(double progress)? onProgress,
  }) async {
    _cancelRequested = false;
    if (!encoder.isSupported) {
      throw const MediaAccessError(MediaFailure.unsupported,
          message: 'Video editing is not available on this platform yet.');
    }
    final src = File(source.path);
    if (!await src.exists()) {
      throw const MediaAccessError(MediaFailure.sourceUnavailable,
          message: 'The original video is no longer available.');
    }
    if (source.width <= 0 || source.height <= 0) {
      throw const MediaAccessError(MediaFailure.corrupt, message: 'This video cannot be edited.');
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final out = File(p.join(tempDir.path, 'video_$stamp.mp4'));
    File? overlayFile;
    try {
      onStage?.call(VideoExportStage.preparing);
      await tempDir.create(recursive: true);
      final plan = planVideoExport(srcWidth: source.width, srcHeight: source.height, state: state);
      if (plan.hasOverlays) {
        overlayFile = File(p.join(tempDir.path, 'overlay_$stamp.png'));
        await overlayFile.writeAsBytes(
          await renderOverlayLayerPng(state.visual.overlays, ui.Size(plan.outWidth.toDouble(), plan.outHeight.toDouble())),
          flush: true,
        );
      }
      _throwIfCancelled();

      onStage?.call(VideoExportStage.encoding);
      final result = await encoder.encode(
        VideoEncodeRequest(
          id: '$stamp',
          inputPath: source.path,
          outputPath: out.path,
          plan: plan,
          overlayPngPath: overlayFile?.path,
        ),
        onProgress: onProgress,
      );
      _throwIfCancelled();

      onStage?.call(VideoExportStage.verifying);
      final info = await tools.describeFile(result.outputPath, MediaKind.video);
      final problem = checkExportedVideo(
        plan,
        width: info.width,
        height: info.height,
        durationMs: info.durationMs,
        hasAudio: info.hasAudio,
        sourceHadAudio: sourceHasAudio,
      );
      if (problem != null) {
        throw MediaAccessError(MediaFailure.verifyFailed, message: problem);
      }

      onStage?.call(VideoExportStage.saving);
      final base = p.basenameWithoutExtension(source.fileName);
      return await library.addCreatedFile(
        result.outputPath,
        fileName: 'edited_$base.mp4',
        mimeType: 'video/mp4',
        kind: MediaKind.video,
        sourceType: SourceType.edited,
        expectedWidth: info.width,
        expectedHeight: info.height,
      );
    } on AppError {
      rethrow;
    } on FileSystemException catch (e) {
      final low = (e.osError?.errorCode == 28) || e.message.contains('No space');
      throw MediaAccessError(
        low ? MediaFailure.lowStorage : MediaFailure.unknown,
        message: low ? 'Not enough free storage to export.' : 'The video could not be exported.',
        cause: e,
      );
    } finally {
      await _deleteQuietly(out);
      if (overlayFile != null) await _deleteQuietly(overlayFile);
    }
  }

  void _throwIfCancelled() {
    if (_cancelRequested) throw const OperationCancelled();
  }

  Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // The OS reclaims the temp directory.
    }
  }
}

/// Renders text/sticker overlays onto a transparent bitmap of exactly [size] pixels.
Future<List<int>> renderOverlayLayerPng(List<EditOverlay> overlays, ui.Size size) async {
  final recorder = ui.PictureRecorder();
  paintOverlays(ui.Canvas(recorder), size, overlays);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw const FileOperationError(message: 'The text layer could not be prepared.');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}
