// lib/features/library/data/media_probe.dart
//
// Validates that a file really is readable media and extracts its facts.
// Used before anything enters the library (docs/MEDIA_PROCESSING_SPEC.md).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:video_player/video_player.dart';

import '../../../core/error/app_error.dart';
import '../domain/library_models.dart';

abstract interface class MediaProbe {
  /// Throws [MediaAccessError] (corrupt) if the file cannot be decoded.
  Future<FileInfo> probe(String path, MediaKind kind);
}

class FlutterMediaProbe implements MediaProbe {
  const FlutterMediaProbe();

  @override
  Future<FileInfo> probe(String path, MediaKind kind) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const MediaAccessError(MediaFailure.sourceUnavailable,
          message: 'This item is no longer available.');
    }
    final size = await file.length();
    if (size <= 0) {
      throw const MediaAccessError(MediaFailure.corrupt, message: 'The file is empty.');
    }
    try {
      if (kind == MediaKind.image) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        try {
          final frame = await codec.getNextFrame();
          final img = frame.image;
          final info = FileInfo(sizeBytes: size, width: img.width, height: img.height);
          img.dispose();
          return info;
        } finally {
          codec.dispose();
        }
      }
      final controller = VideoPlayerController.file(file);
      try {
        await controller.initialize();
        final v = controller.value;
        if (v.duration == Duration.zero || v.size.width <= 0) {
          throw const FormatException('empty video');
        }
        return FileInfo(
          sizeBytes: size,
          width: v.size.width.round(),
          height: v.size.height.round(),
          durationMs: v.duration.inMilliseconds,
        );
      } finally {
        await controller.dispose();
      }
    } on MediaAccessError {
      rethrow;
    } catch (e) {
      throw MediaAccessError(MediaFailure.corrupt,
          message: 'This file is damaged or in an unsupported format.', cause: e);
    }
  }
}
