// lib/features/indexing/domain/indexing_models.dart
//
// Pure domain models for the indexing engine.
// No Flutter or Drift imports — plain Dart.

/// Scan status mirroring the Kotlin ScanStatus constants.
enum ScanStatus { idle, running, paused, cancelled, done, error }

/// Immutable progress snapshot emitted by the indexing stream (REQ-IDX-05).
/// All values are from real data — never interpolated (P-03).
class ScanProgress {
  const ScanProgress({
    required this.status,
    required this.itemsProcessed,
    required this.itemsTotal,
    required this.bytesProcessed,
    this.scanVersion = 0,
    this.generation = 0,
    this.error,
  });

  final ScanStatus status;

  /// Monotonically non-decreasing (REQ-IDX-05).
  final int itemsProcessed;

  /// Total items discovered so far. May grow as we learn the full count.
  final int itemsTotal;

  /// Bytes processed so far.
  final int bytesProcessed;

  final int scanVersion;
  final int generation;
  final String? error;

  /// Progress fraction 0.0–1.0. Returns 0 when total is unknown.
  double get fraction =>
      itemsTotal > 0 ? (itemsProcessed / itemsTotal).clamp(0.0, 1.0) : 0.0;

  bool get isTerminal =>
      status == ScanStatus.done ||
      status == ScanStatus.cancelled ||
      status == ScanStatus.error;

  /// Convenience: is the scan actively running?
  bool get isActive => status == ScanStatus.running;

  ScanProgress copyWith({
    ScanStatus? status,
    int? itemsProcessed,
    int? itemsTotal,
    int? bytesProcessed,
    int? scanVersion,
    int? generation,
    String? error,
  }) =>
      ScanProgress(
        status: status ?? this.status,
        itemsProcessed: itemsProcessed ?? this.itemsProcessed,
        itemsTotal: itemsTotal ?? this.itemsTotal,
        bytesProcessed: bytesProcessed ?? this.bytesProcessed,
        scanVersion: scanVersion ?? this.scanVersion,
        generation: generation ?? this.generation,
        error: error ?? this.error,
      );

  @override
  String toString() =>
      'ScanProgress($status, $itemsProcessed/$itemsTotal, ${bytesProcessed}B)';
}

/// A single media item as received from the Kotlin platform channel.
/// Converted to a Drift companion before DB insertion.
class RawMediaItem {
  const RawMediaItem({
    required this.contentUri,
    required this.mediaStoreId,
    required this.displayName,
    required this.mimeType,
    required this.sizeBytes,
    required this.dateAddedSec,
    required this.dateModifiedSec,
    required this.bucketName,
    required this.sourceApp,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.scanVersion,
  });

  final String contentUri;
  final String mediaStoreId;
  final String displayName;
  final String mimeType;
  final int sizeBytes;
  final int dateAddedSec;
  final int dateModifiedSec;
  final String bucketName;
  final String sourceApp;
  final int width;
  final int height;
  final int durationMs;
  final int scanVersion;

  factory RawMediaItem.fromMap(Map<Object?, Object?> map, int scanVersion) {
    return RawMediaItem(
      contentUri:      map['contentUri'] as String? ?? '',
      mediaStoreId:    map['mediaStoreId'] as String? ?? '',
      displayName:     map['displayName'] as String? ?? '',
      mimeType:        map['mimeType'] as String? ?? '',
      sizeBytes:       (map['sizeBytes'] as num?)?.toInt() ?? 0,
      dateAddedSec:    (map['dateAddedSec'] as num?)?.toInt() ?? 0,
      dateModifiedSec: (map['dateModifiedSec'] as num?)?.toInt() ?? 0,
      bucketName:      map['bucketName'] as String? ?? '',
      sourceApp:       map['sourceApp'] as String? ?? 'com.whatsapp',
      width:           (map['width'] as num?)?.toInt() ?? 0,
      height:          (map['height'] as num?)?.toInt() ?? 0,
      durationMs:      (map['durationMs'] as num?)?.toInt() ?? 0,
      scanVersion:     scanVersion,
    );
  }
}
