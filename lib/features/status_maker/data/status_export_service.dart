// lib/features/status_maker/data/status_export_service.dart
//
// Renders a text status to a 1080x1920 PNG, verifies it by decoding it back, and
// adds it to the library as a "created" item.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/error/app_error.dart';
import '../../library/data/library_service.dart';
import '../../library/domain/library_models.dart';
import '../domain/status_renderer.dart';

enum StatusExportStage {
  rendering('Rendering'),
  saving('Saving');

  const StatusExportStage(this.label);
  final String label;
}

class StatusExportService {
  StatusExportService({required this.library, required this.tempDir, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final LibraryService library;
  final Directory tempDir;
  final DateTime Function() _clock;

  Future<SavedMedia> export(
    StatusDraft draft, {
    void Function(StatusExportStage stage)? onStage,
  }) async {
    if (draft.text.trim().isEmpty) {
      throw const FileOperationError(message: 'Type a message first.');
    }
    ui.Image? image;
    File? temp;
    try {
      onStage?.call(StatusExportStage.rendering);
      image = await renderStatusImage(draft);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const FileOperationError(message: 'The status could not be rendered.');
      }
      onStage?.call(StatusExportStage.saving);
      await tempDir.create(recursive: true);
      temp = File(p.join(tempDir.path, 'status_${_clock().microsecondsSinceEpoch}.png'));
      await temp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      final stamp = _clock();
      String two(int n) => n.toString().padLeft(2, '0');
      return await library.addCreatedFile(
        temp.path,
        fileName: 'status_${stamp.year}${two(stamp.month)}${two(stamp.day)}_${two(stamp.hour)}${two(stamp.minute)}${two(stamp.second)}.png',
        mimeType: 'image/png',
        kind: MediaKind.image,
        sourceType: SourceType.created,
        expectedWidth: kStatusExportSize.width.round(),
        expectedHeight: kStatusExportSize.height.round(),
      );
    } on AppError {
      rethrow;
    } on FileSystemException catch (e) {
      final low = (e.osError?.errorCode == 28) || e.message.contains('No space');
      throw MediaAccessError(
        low ? MediaFailure.lowStorage : MediaFailure.unknown,
        message: low ? 'Not enough free storage to save.' : 'The status could not be saved.',
        cause: e,
      );
    } finally {
      image?.dispose();
      if (temp != null && await temp.exists()) {
        try {
          await temp.delete();
        } on FileSystemException {
          // OS reclaims the temp directory.
        }
      }
    }
  }
}
