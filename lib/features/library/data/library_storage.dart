// lib/features/library/data/library_storage.dart
//
// Owns the on-disk layout of the WazApp library (app-private storage).
//   <support>/library/<id>.<ext>   media files
//   <support>/thumbs/<id>.jpg      cached video thumbnails
//   <support>/private/<id>.<ext>   Private Folder media (same app-private area, separate directory)
//   <support>/private_thumbs/<id>.jpg
// Everything lives in the app's private storage; nothing here is encrypted.

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

  Directory get privateDir => Directory(p.join(root.path, 'private'));
  Directory get privateThumbsDir => Directory(p.join(root.path, 'private_thumbs'));

  List<Directory> get _allDirs => [mediaDir, thumbsDir, privateDir, privateThumbsDir];

  Future<void> ensureCreated() async {
    for (final d in _allDirs) {
      await d.create(recursive: true);
    }
  }

  static final Random _rng = Random.secure();

  /// 128-bit random id as hex.
  String newId() =>
      List.generate(16, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  String mediaPath(String id, String extension) => p.join(mediaDir.path, '$id.$extension');
  String thumbPath(String id) => p.join(thumbsDir.path, '$id.jpg');
  String privatePath(String id, String extension) => p.join(privateDir.path, '$id.$extension');
  String privateThumbPath(String id) => p.join(privateThumbsDir.path, '$id.jpg');

  /// Removes leftovers of interrupted copies (`*.part`) so storage is not silently wasted.
  Future<int> cleanPartialFiles() async {
    var removed = 0;
    for (final dir in [mediaDir, privateDir]) {
      if (!await dir.exists()) continue;
      await for (final e in dir.list()) {
        if (e is File && e.path.endsWith('.part')) {
          try {
            await e.delete();
            removed++;
          } on FileSystemException {
            // Leave it; it will be retried on next launch.
          }
        }
      }
    }
    return removed;
  }

  /// Bytes used on disk by everything WazApp keeps (library, private, thumbnails).
  Future<int> usedBytes() async {
    var total = 0;
    for (final dir in _allDirs) {
      if (!await dir.exists()) continue;
      await for (final e in dir.list()) {
        if (e is File) total += await e.length();
      }
    }
    return total;
  }
}
