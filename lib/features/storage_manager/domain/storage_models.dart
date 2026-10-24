// lib/features/storage_manager/domain/storage_models.dart
//
// Plain data + pure helpers for the Storage Manager. Everything here describes
// files WazApp keeps itself; it never reports on files outside the app's own storage.

import 'package:equatable/equatable.dart';

import '../../../core/database/app_database.dart';

/// Why items were grouped together. Both are warnings only - nothing is deleted automatically.
enum DuplicateReason {
  /// Byte-for-byte the same file (same size and same SHA-256).
  identical(
    'Identical files',
    'These files have exactly the same content (same size and SHA-256 fingerprint).',
  ),

  /// Photos that look the same (same shape, very similar 8x8 brightness pattern).
  lookAlike(
    'Look-alike photos',
    'These photos have the same shape and an almost identical brightness pattern, so they are probably the same '
        'picture saved twice (for example resized or re-compressed). They are not byte-identical - check before deleting.',
  );

  const DuplicateReason(this.title, this.explanation);
  final String title;
  final String explanation;
}

class DuplicateGroup extends Equatable {
  const DuplicateGroup({required this.reason, required this.items});

  final DuplicateReason reason;

  /// At least two items, oldest first.
  final List<SavedMedia> items;

  /// Bytes freed if all but one item were removed.
  int get reclaimableBytes => items.skip(1).fold(0, (a, m) => a + m.sizeBytes);

  /// The suggestion: keep the oldest (the original), the rest are "extras". The user must still confirm.
  List<SavedMedia> get suggestedExtras => items.skip(1).toList();

  @override
  List<Object?> get props => [reason, items.map((m) => m.id).toList()];
}

/// A file inside WazApp's directories that no library row points to.
class UnreferencedFile extends Equatable {
  const UnreferencedFile(this.path, this.sizeBytes);
  final String path;
  final int sizeBytes;

  @override
  List<Object?> get props => [path, sizeBytes];
}

class SourceUsage extends Equatable {
  const SourceUsage(this.count, this.bytes);
  final int count;
  final int bytes;

  @override
  List<Object?> get props => [count, bytes];
}

/// What WazApp really occupies, measured from the file system (not from stored metadata).
class StorageReport extends Equatable {
  const StorageReport({
    required this.photos,
    required this.videos,
    required this.privateItems,
    required this.thumbnailBytes,
    required this.tempBytes,
    required this.unreferenced,
    required this.missingIds,
    required this.bySource,
    required this.largeFiles,
  });

  /// Non-private photos / videos.
  final SourceUsage photos;
  final SourceUsage videos;

  /// Private Folder: only the totals are exposed, never names or thumbnails.
  final SourceUsage privateItems;

  /// Thumbnails of normal and private items.
  final int thumbnailBytes;

  /// Scratch files of exports in progress or interrupted.
  final int tempBytes;

  /// Files on disk that no row refers to (still occupy space).
  final List<UnreferencedFile> unreferenced;

  /// Rows whose media file no longer exists (non-private and private).
  final List<String> missingIds;

  /// Non-private items by origin: status / imported / created / edited.
  final Map<String, SourceUsage> bySource;

  /// Biggest non-private files, largest first.
  final List<SavedMedia> largeFiles;

  int get unreferencedBytes => unreferenced.fold(0, (a, f) => a + f.sizeBytes);

  /// Everything WazApp keeps on this device.
  int get totalBytes =>
      photos.bytes +
      videos.bytes +
      privateItems.bytes +
      thumbnailBytes +
      tempBytes +
      unreferencedBytes;

  @override
  List<Object?> get props => [
    photos,
    videos,
    privateItems,
    thumbnailBytes,
    tempBytes,
    unreferenced,
    missingIds,
    bySource,
    largeFiles.map((m) => m.id).toList(),
  ];
}

// -----------------------------------------------------------------------------
// Visual fingerprint helpers (pure)
// -----------------------------------------------------------------------------

/// 64-bit difference hash from a 9x8 grayscale grid (row-major, 72 values): bit = left pixel brighter than right.
String dHashFromGray9x8(List<int> gray) {
  assert(gray.length == 72);
  final nibbles = StringBuffer();
  var bits = <int>[];
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      bits.add(gray[y * 9 + x] > gray[y * 9 + x + 1] ? 1 : 0);
      if (bits.length == 4) {
        nibbles.write(
          (bits[0] << 3 | bits[1] << 2 | bits[2] << 1 | bits[3]).toRadixString(
            16,
          ),
        );
        bits = <int>[];
      }
    }
  }
  return nibbles.toString();
}

int _popcount4(int v) =>
    (v & 1) + ((v >> 1) & 1) + ((v >> 2) & 1) + ((v >> 3) & 1);

/// Number of differing bits between two 16-hex-digit hashes.
int hammingHex(String a, String b) {
  if (a.length != b.length) return 64;
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d += _popcount4(int.parse(a[i], radix: 16) ^ int.parse(b[i], radix: 16));
  }
  return d;
}

/// Max differing bits (of 64) for two photos to count as look-alikes.
const int kLookAlikeMaxHamming = 4;

/// Largest relative difference of aspect ratios for look-alikes (rejects crops/rotations).
const double kLookAlikeAspectTolerance = 0.02;

bool similarShape(SavedMedia a, SavedMedia b) {
  if (a.width <= 0 || a.height <= 0 || b.width <= 0 || b.height <= 0) {
    return false;
  }
  final ra = a.width / a.height, rb = b.width / b.height;
  return (ra - rb).abs() / ra <= kLookAlikeAspectTolerance;
}
