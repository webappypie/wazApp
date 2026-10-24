// lib/core/services/media_access/media_item.dart
//
// Domain model for an indexed media file (REQ-IDX-02).
//
// All fields mirror the columns persisted in the Drift DB (Phase 3).
// This model lives in core/services so both the media_access service
// and the domain layer can share it without circular imports.

import 'package:equatable/equatable.dart';

/// Identifies which chat app a media file came from (REQ-IDX-06).
enum MediaSource {
  whatsApp('com.whatsapp', id: 'whatsapp', displayName: 'WhatsApp', shortLabel: 'WA', badgeLabel: 'WhatsApp'),
  whatsAppBusiness('com.whatsapp.w4b', id: 'whatsapp_business', displayName: 'WhatsApp Business', shortLabel: 'Business', badgeLabel: 'Business'),
  legacyWhatsApp('legacy', id: 'whatsapp_legacy', displayName: 'WhatsApp (Legacy)', shortLabel: 'WA', badgeLabel: 'WhatsApp'),
  unknown('', id: 'unknown', displayName: 'Unknown', shortLabel: '?', badgeLabel: 'Unknown');

  const MediaSource(
    this.packageName, {
    required this.id,
    required this.displayName,
    required this.shortLabel,
    required this.badgeLabel,
  });

  final String packageName;
  final String id;
  final String displayName;
  final String shortLabel;
  final String badgeLabel;

  bool get isWhatsApp => this == MediaSource.whatsApp || this == MediaSource.legacyWhatsApp;
  bool get isBusiness => this == MediaSource.whatsAppBusiness;

  static MediaSource fromPackageName(String? pkg) {
    if (pkg == null || pkg.isEmpty) return MediaSource.unknown;
    return MediaSource.values.firstWhere(
      (s) => s.packageName == pkg,
      orElse: () => pkg.toLowerCase().contains('w4b') || pkg.toLowerCase().contains('business')
          ? MediaSource.whatsAppBusiness
          : MediaSource.whatsApp,
    );
  }

  static MediaSource fromId(String? id) {
    if (id == null || id.isEmpty) return MediaSource.unknown;
    return MediaSource.values.firstWhere(
      (s) => s.id == id,
      orElse: () => MediaSource.unknown,
    );
  }

  static MediaSource fromPackageOrPath(String? pkg, String? path) {
    final combined = '${pkg ?? ""} ${path ?? ""}'.toLowerCase();
    if (combined.contains('w4b') || combined.contains('business')) {
      return MediaSource.whatsAppBusiness;
    }
    if (combined.contains('whatsapp')) {
      return MediaSource.whatsApp;
    }
    return MediaSource.fromPackageName(pkg);
  }
}

/// A single media file discovered via MediaStore (REQ-IDX-02).
class MediaItem extends Equatable {
  const MediaItem({
    required this.mediaId,
    required this.contentUri,
    required this.mimeType,
    required this.sizeBytes,
    required this.dateAddedEpochSec,
    required this.dateModifiedEpochSec,
    required this.folderBucket,
    required this.source,
    this.width,
    this.height,
    this.durationMs,
  });

  /// MediaStore _ID — stable for the lifetime of the file.
  final int mediaId;

  /// content:// URI — used for all read/write/delete operations.
  final String contentUri;

  final String mimeType;
  final int sizeBytes;

  final int dateAddedEpochSec;
  final int dateModifiedEpochSec;

  /// MediaStore bucket (folder) name, e.g. "WhatsApp Images".
  final String folderBucket;

  final MediaSource source;

  // Image/video dimensions (null for audio).
  final int? width;
  final int? height;

  // Video/audio duration in milliseconds (null for images).
  final int? durationMs;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');

  @override
  List<Object?> get props => [mediaId, contentUri];

  @override
  String toString() => 'MediaItem(id=$mediaId, mime=$mimeType, size=$sizeBytes)';
}
