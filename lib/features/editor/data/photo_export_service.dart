// lib/features/editor/data/photo_export_service.dart
//
// Full-resolution export of a photo edit:
//   decode (bounded) -> render -> JPEG encode (background isolate) -> verify -> library.
// The original file is only ever read. Any failure or cancellation removes all
// partial output.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/error/app_error.dart';
import '../../library/data/library_service.dart';
import '../../library/domain/library_models.dart';
import '../domain/edit_state.dart';
import '../domain/photo_renderer.dart';

enum ExportStage {
  decoding('Reading photo'),
  rendering('Applying edits'),
  encoding('Compressing'),
  saving('Saving');

  const ExportStage(this.label);
  final String label;
}

/// JPEG-encodes raw RGBA pixels. Runs in a background isolate.
Uint8List encodeRgbaToJpeg(({Uint8List rgba, int width, int height, int quality}) args) {
  final image = img.Image.fromBytes(
    width: args.width,
    height: args.height,
    bytes: args.rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: args.quality));
}

class PhotoExportService {
  PhotoExportService({required this.library, required this.tempDir, this.jpegQuality = 92});

  final LibraryService library;
  final Directory tempDir;
  final int jpegQuality;

  /// Exports [source] with [state] as a NEW library item; [source] is left untouched.
  Future<SavedMedia> exportPhoto({
    required SavedMedia source,
    required EditState state,
    double maxDimension = 4096,
    void Function(ExportStage stage)? onStage,
    bool Function()? isCancelled,
  }) async {
    void checkCancel() {
      if (isCancelled?.call() ?? false) throw const OperationCancelled();
    }

    final file = File(source.path);
    if (!await file.exists()) {
      throw const MediaAccessError(MediaFailure.sourceUnavailable,
          message: 'The original photo is no longer available.');
    }

    ui.Image? decoded;
    ui.Image? rendered;
    File? temp;
    try {
      // 1. Decode, bounded so a 50 MP photo cannot exhaust memory.
      onStage?.call(ExportStage.decoding);
      final bytes = await file.readAsBytes();
      checkCancel();
      decoded = await _decodeBounded(bytes, state, source, maxDimension);
      checkCancel();

      // 2. Render exactly what the preview shows, at full frame size.
      onStage?.call(ExportStage.rendering);
      final src = ui.Size(decoded.width.toDouble(), decoded.height.toDouble());
      final out = exportSize(src, state, maxDimension: double.infinity);
      rendered = await renderEditToImage(decoded, state, out);
      checkCancel();

      // 3. Encode off the UI isolate.
      onStage?.call(ExportStage.encoding);
      final raw = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw == null) {
        throw const FileOperationError(message: 'The edited photo could not be rendered.');
      }
      final jpeg = await compute(encodeRgbaToJpeg, (
        rgba: raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
        width: rendered.width,
        height: rendered.height,
        quality: jpegQuality,
      ));
      checkCancel();

      // 4. Write, verify (decode + exact size) and register.
      onStage?.call(ExportStage.saving);
      await tempDir.create(recursive: true);
      temp = File(p.join(tempDir.path, 'export_${DateTime.now().microsecondsSinceEpoch}.jpg'));
      await temp.writeAsBytes(jpeg, flush: true);
      final base = p.basenameWithoutExtension(source.fileName);
      return await library.addCreatedFile(
        temp.path,
        fileName: 'edited_$base.jpg',
        mimeType: 'image/jpeg',
        kind: MediaKind.image,
        sourceType: SourceType.edited,
        expectedWidth: rendered.width,
        expectedHeight: rendered.height,
      );
    } on AppError {
      rethrow;
    } on FileSystemException catch (e) {
      final low = (e.osError?.errorCode == 28) || e.message.contains('No space');
      throw MediaAccessError(
        low ? MediaFailure.lowStorage : MediaFailure.unknown,
        message: low ? 'Not enough free storage to export.' : 'The photo could not be exported.',
        cause: e,
      );
    } catch (e) {
      throw MediaAccessError(MediaFailure.corrupt,
          message: 'The photo could not be processed. It may be damaged or unsupported.', cause: e);
    } finally {
      decoded?.dispose();
      rendered?.dispose();
      if (temp != null && await temp.exists()) {
        try {
          await temp.delete();
        } on FileSystemException {
          // Left in the temp directory; the OS reclaims it.
        }
      }
    }
  }

  Future<ui.Image> _decodeBounded(Uint8List bytes, EditState s, SavedMedia source, double maxDimension) async {
    // Plan the decode size from the recorded dimensions so we never decode more than needed.
    var targetWidth = 0;
    if (source.width > 0 && source.height > 0) {
      final frame = s.frameSize(ui.Size(source.width.toDouble(), source.height.toDouble()));
      final longest = frame.width > frame.height ? frame.width : frame.height;
      if (longest > maxDimension) {
        targetWidth = (source.width * maxDimension / longest).round().clamp(1, source.width);
      }
    }
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth > 0 ? targetWidth : null);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
}
