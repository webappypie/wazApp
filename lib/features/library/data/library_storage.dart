// lib/features/library/data/library_storage.dart
//
// Owns the on-disk layout of the WazApp library (app-private storage).
//   <support>/library/<id>.<ext>   media files
//   <support>/thumbs/<id>.jpg      cached video thumbnails

import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LibraryStorage {
  LibraryStorage(this.root);

  final Directory root;

  static Future<LibraryStorage> open() async =>
      LibraryStorage(await getApplicationSupportDirectory());

  Directory get mediaDir => Directory(p.join(root.path, 'library'));
  Directory get thumbsDir => Directory(p.join(root.path, 'thumbs'));

  Future<void> ensureCreated() async {
    await mediaDir.create(recursive: true);
    await thumbsDir.create(recursive: true);
  }

  static final Random _rng = Random.secure();

  /// 128-bit random id as hex.
  String newId() =>
      List.generate(16, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  String mediaPath(String id, String extension) => p.join(mediaDir.path, '$id.$extension');
  String thumbPath(String id) => p.join(thumbsDir.path, '$id.jpg');

  /// Free bytes are checked by the native copy; this removes leftovers of
  /// interrupted copies (`*.part`) so storage is not silently wasted.
  Future<int> cleanPartialFiles() async {
    var removed = 0;
    if (!await mediaDir.exists()) return 0;
    await for (final e in mediaDir.list()) {
      if (e is File && e.path.endsWith('.part')) {
        try {
          await e.delete();
          removed++;
        } on FileSystemException {
          // Leave it; it will be retried on next launch.
        }
      }
    }
    return removed;
  }

  /// Total bytes used by library media and thumbnails.
  Future<int> usedBytes() async {
    var total = 0;
    for (final dir in [mediaDir, thumbsDir]) {
      if (!await dir.exists()) continue;
      await for (final e in dir.list()) {
        if (e is File) total += await e.length();
      }
    }
    return total;
  }
}
