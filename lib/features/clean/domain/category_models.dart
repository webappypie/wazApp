// lib/features/clean/domain/category_models.dart
//
// Pure domain models for the Category framework (REQ-CLN-01).
// Generic and decoupled from specific categories (Phase 6).

import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Represents a single media item displayed in a category screen.
class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.contentUri,
    required this.displayName,
    required this.mimeType,
    required this.sizeBytes,
    required this.dateAddedSec,
    required this.dateModifiedSec,
    required this.bucketName,
    required this.sourceApp,
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
    this.isProtected = false,
    this.thumbnailProvider,
    this.groupTitle,
    this.badgeLabel,
    this.isOriginal = false,
  });

  final String id;
  final String contentUri;
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
  final bool isProtected;
  final ImageProvider? thumbnailProvider;
  final String? groupTitle;
  final String? badgeLabel;
  final bool isOriginal;

  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');
  bool get isImage => mimeType.startsWith('image/');

  String get formattedSize => formatBytes(sizeBytes);

  String? get formattedDuration {
    if (durationMs <= 0) return null;
    final totalSec = (durationMs / 1000).round();
    final minutes = totalSec ~/ 60;
    final seconds = totalSec % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Default transparent placeholder image when no thumbnail provider is available.
  static final ImageProvider defaultPlaceholder = MemoryImage(
    Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
      0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
      0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
      0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
      0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND chunk
      0x44, 0xAE, 0x42, 0x60, 0x82,
    ]),
  );

  ImageProvider get safeThumbnail => thumbnailProvider ?? defaultPlaceholder;
}

/// Sort criteria for category items.
enum CategorySortKey {
  dateModified,
  size,
  name,
}

/// Order direction.
enum SortDirection {
  ascending,
  descending,
}

/// A sort option specification.
class CategorySortOption {
  const CategorySortOption({
    required this.label,
    required this.key,
    required this.direction,
  });

  final String label;
  final CategorySortKey key;
  final SortDirection direction;

  static const defaultOptions = [
    CategorySortOption(
      label: 'Newest first',
      key: CategorySortKey.dateModified,
      direction: SortDirection.descending,
    ),
    CategorySortOption(
      label: 'Oldest first',
      key: CategorySortKey.dateModified,
      direction: SortDirection.ascending,
    ),
    CategorySortOption(
      label: 'Largest first',
      key: CategorySortKey.size,
      direction: SortDirection.descending,
    ),
    CategorySortOption(
      label: 'Smallest first',
      key: CategorySortKey.size,
      direction: SortDirection.ascending,
    ),
    CategorySortOption(
      label: 'Name (A-Z)',
      key: CategorySortKey.name,
      direction: SortDirection.ascending,
    ),
    CategorySortOption(
      label: 'Name (Z-A)',
      key: CategorySortKey.name,
      direction: SortDirection.descending,
    ),
  ];
}

/// Filter option for filtering category items.
class CategoryFilterOption {
  const CategoryFilterOption({
    required this.label,
    required this.predicate,
  });

  final String label;
  final bool Function(CategoryItem item) predicate;
}

/// View display mode for category items (Grid vs List).
enum CategoryViewMode {
  grid,
  list,
}

/// Format bytes into human readable string (P-03: accurate formatting).
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}
