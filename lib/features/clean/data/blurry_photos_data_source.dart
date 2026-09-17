// lib/features/clean/data/blurry_photos_data_source.dart
//
// Data source for Blurry Photos category (REQ-BLR-01).
//
// RULES:
//   - REQ-BLR-01: Two confidence tiers ("Very Blurry" / "Possibly Blurry").
//   - Excludes protected items (REQ-ACT-05).
//   - Only pre-selects "Very Blurry" items by default; "Possibly Blurry" unselected.
//   - Labeled "Very Blurry" or "Possibly Blurry", NEVER "Safe to delete".

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../domain/blur_detector.dart';
import '../domain/category_data_source.dart';
import '../domain/category_models.dart';

class BlurryPhotosDataSource extends CategoryDataSource {
  BlurryPhotosDataSource({
    this.db,
    List<CategoryItem>? mockItems,
    this.mockScores,
  }) : _mockItems = mockItems != null ? List.from(mockItems) : null;

  final AppDatabase? db;
  final List<CategoryItem>? _mockItems;
  final Map<String, BlurEvaluation>? mockScores;

  static const _channel = MethodChannel('com.wapptidy/blur_detector');

  final Set<String> _veryBlurryIds = {};
  int _totalPotentialSavings = 0;

  Set<String> get defaultPreselectedIds => Set.unmodifiable(_veryBlurryIds);
  int get totalPotentialSavings => _totalPotentialSavings;

  @override
  Future<List<CategoryItem>> getItems() async {
    _veryBlurryIds.clear();
    _totalPotentialSavings = 0;

    List<CategoryItem> rawItems;
    if (_mockItems != null) {
      // Exclude protected items (REQ-ACT-05)
      rawItems = _mockItems.where((item) => !item.isProtected).toList();
    } else if (db != null) {
      final dbItems = await (db!.select(db!.mediaItems)
            ..where((t) =>
                t.mimeType.like('image/%') & t.isProtected.equals(false)))
          .get();

      rawItems = dbItems.map((row) {
        return CategoryItem(
          id: row.id.toString(),
          contentUri: row.contentUri,
          displayName: row.displayName,
          mimeType: row.mimeType,
          sizeBytes: row.sizeBytes,
          dateAddedSec: row.dateAddedSec,
          dateModifiedSec: row.dateModifiedSec,
          bucketName: row.bucketName,
          sourceApp: row.sourceApp,
          width: row.width,
          height: row.height,
          isProtected: row.isProtected,
        );
      }).toList();
    } else {
      return [];
    }

    if (rawItems.isEmpty) return [];

    final evaluations = <String, BlurEvaluation>{};

    if (mockScores != null) {
      evaluations.addAll(mockScores!);
    } else {
      try {
        final uris = rawItems.map((e) => e.contentUri).toList();
        final rawMap = await _channel.invokeMethod<Map<Object?, Object?>>(
          'computeBatchBlurScores',
          {'uris': uris},
        );

        if (rawMap != null) {
          for (final entry in rawMap.entries) {
            final uri = entry.key?.toString();
            final data = entry.value;
            if (uri != null && data is Map) {
              final globalVar = (data['globalVariance'] as num?)?.toDouble() ?? 0.0;
              final maxBlockVar = (data['maxBlockVariance'] as num?)?.toDouble() ?? 0.0;
              evaluations[uri] = BlurDetector.evaluate(
                globalVariance: globalVar,
                maxBlockVariance: maxBlockVar,
              );
            }
          }
        }
      } catch (_) {
        // Fallback for tests or unsupported environments
      }
    }

    final veryBlurryList = <CategoryItem>[];
    final possiblyBlurryList = <CategoryItem>[];

    for (final item in rawItems) {
      final eval = evaluations[item.contentUri] ??
          const BlurEvaluation(
            globalVariance: 500.0,
            maxBlockVariance: 500.0,
            confidence: BlurConfidence.sharp,
          );

      if (eval.confidence == BlurConfidence.veryBlurry) {
        _veryBlurryIds.add(item.id);
        _totalPotentialSavings += item.sizeBytes;
        veryBlurryList.add(
          item.copyWith(
            badgeLabel: 'Very Blurry',
            groupTitle: 'Very Blurry Photos',
          ),
        );
      } else if (eval.confidence == BlurConfidence.possiblyBlurry) {
        possiblyBlurryList.add(
          item.copyWith(
            badgeLabel: 'Possibly Blurry',
            groupTitle: 'Possibly Blurry Photos',
          ),
        );
      }
    }

    return [...veryBlurryList, ...possiblyBlurryList];
  }
}
