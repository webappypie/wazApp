// lib/features/library/domain/library_models.dart
//
// Shared media vocabulary for the local library.

import '../../../core/database/app_database.dart';

enum MediaKind {
  image,
  video;

  static MediaKind parse(String raw) => raw == 'video' ? MediaKind.video : MediaKind.image;
}

/// Where a library item came from.
enum SourceType { status, imported, created, edited }

/// Technical facts about a verified media file.
class FileInfo {
  const FileInfo({
    required this.sizeBytes,
    required this.width,
    required this.height,
    this.durationMs = 0,
    this.hasAudio = false,
  });

  final int sizeBytes;
  final int width;
  final int height;
  final int durationMs;

  /// Videos only: whether an audio track is present.
  final bool hasAudio;
}

extension SavedMediaX on SavedMedia {
  MediaKind get mediaKind => MediaKind.parse(kind);
  bool get isVideo => mediaKind == MediaKind.video;
  Duration get duration => Duration(milliseconds: durationMs);
}

/// Filter chips on the Saved screen.
enum LibraryFilter {
  all('All'),
  photos('Photos'),
  videos('Videos'),
  favourites('Favourites'),
  recent('Recent');

  const LibraryFilter(this.label);
  final String label;
}

/// Pure filter+search so the behaviour is unit-testable.
List<SavedMedia> applyLibraryFilter(
  List<SavedMedia> items, {
  required LibraryFilter filter,
  String query = '',
  DateTime? now,
}) {
  final q = query.trim().toLowerCase();
  final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 7));
  return items.where((m) {
    switch (filter) {
      case LibraryFilter.all:
        break;
      case LibraryFilter.photos:
        if (m.mediaKind != MediaKind.image) return false;
      case LibraryFilter.videos:
        if (m.mediaKind != MediaKind.video) return false;
      case LibraryFilter.favourites:
        if (!m.isFavourite) return false;
      case LibraryFilter.recent:
        if (m.savedAt.isBefore(cutoff)) return false;
    }
    if (q.isEmpty) return true;
    final haystack = [
      m.fileName,
      m.kind,
      m.sourceType,
      if (m.sourceApp == 'business') 'whatsapp business',
      if (m.sourceApp == 'whatsapp') 'whatsapp',
      if (m.sourceType == 'status') 'status',
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }).toList(growable: false);
}
