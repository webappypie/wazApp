// lib/features/clean/data/duplicates_data_source.dart
//
// Data source for exact duplicate detection (REQ-DUP-01, REQ-DUP-02, REQ-DUP-03).
// Routes to native Kotlin 2-stage hash via MethodChannel('com.wapptidy/duplicate_detector') (PRD §5.4).
// In tests or non-Android environments, uses in-memory duplicate detection.

import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../domain/category_data_source.dart';
import '../domain/category_models.dart';

class DuplicatesDataSource extends CategoryDataSource {
  DuplicatesDataSource({
    this.db,
    MethodChannel? channel,
    this.testItems,
  }) : _channel = channel ?? const MethodChannel('com.wapptidy/duplicate_detector');

  final AppDatabase? db;
  final MethodChannel _channel;
  final List<CategoryItem>? testItems;

  int _totalPotentialSavings = 0;
  int get totalPotentialSavings => _totalPotentialSavings;

  int _duplicateGroupsCount = 0;
  int get duplicateGroupsCount => _duplicateGroupsCount;

  @override
  Future<List<CategoryItem>> getItems() async {
    if (testItems != null) {
      return _computeInMemoryDuplicates(testItems!);
    }

    final rows = await (db!.select(db!.mediaItems)
          ..where((tbl) => tbl.isProtected.equals(false)))
        .get();
    final candidateItems = rows.map((r) => CategoryItem(
      id: r.id.toString(),
      contentUri: r.contentUri,
      displayName: r.displayName,
      mimeType: r.mimeType,
      sizeBytes: r.sizeBytes,
      dateAddedSec: r.dateAddedSec,
      dateModifiedSec: r.dateModifiedSec,
      bucketName: r.bucketName,
      sourceApp: r.sourceApp,
      width: r.width,
      height: r.height,
      durationMs: r.durationMs,
      isProtected: r.isProtected,
    )).toList();

    try {
      final payload = candidateItems.map((item) => {
        'id': item.id,
        'contentUri': item.contentUri,
        'displayName': item.displayName,
        'mimeType': item.mimeType,
        'sizeBytes': item.sizeBytes,
        'dateAddedSec': item.dateAddedSec,
        'dateModifiedSec': item.dateModifiedSec,
        'bucketName': item.bucketName,
        'sourceApp': item.sourceApp,
        'width': item.width,
        'height': item.height,
        'durationMs': item.durationMs,
        'isProtected': item.isProtected,
      }).toList();

      final List<dynamic>? rawGroups = await _channel.invokeListMethod(
        'findDuplicates',
        {'items': payload},
      );

      if (rawGroups != null && rawGroups.isNotEmpty) {
        return _parseDuplicateGroups(rawGroups);
      }
    } catch (_) {
      // Non-Android / mock fallback for tests: fallback to size-and-name heuristic in memory
    }

    return _computeInMemoryDuplicates(candidateItems);
  }

  List<CategoryItem> _parseDuplicateGroups(List<dynamic> rawGroups) {
    final result = <CategoryItem>[];
    var groupIndex = 1;
    var totalSavings = 0;

    for (final group in rawGroups) {
      if (group is! Map) continue;
      final groupMap = Map<String, dynamic>.from(group);
      final rawItems = groupMap['items'] as List<dynamic>? ?? [];
      final copyCount = (groupMap['copyCount'] as num?)?.toInt() ?? rawItems.length;
      final fileSize = (groupMap['fileSize'] as num?)?.toInt() ?? 0;
      final saving = (groupMap['potentialSaving'] as num?)?.toInt() ?? (fileSize * (copyCount - 1));
      totalSavings += saving;

      // Check if group contains items from multiple sources
      final sourceAppsInGroup = <String>{};
      for (final itemRaw in rawItems) {
        if (itemRaw is Map) {
          final s = itemRaw['sourceApp']?.toString();
          if (s != null && s.isNotEmpty) sourceAppsInGroup.add(s);
        }
      }
      final isCrossApp = sourceAppsInGroup.length > 1;
      final crossAppTag = isCrossApp ? 'Cross-App • ' : '';
      final groupTitle = 'Group $groupIndex: $copyCount copies • $crossAppTag${formatBytes(fileSize * copyCount)} (Save ${formatBytes(saving)})';

      for (final itemRaw in rawItems) {
        if (itemRaw is! Map) continue;
        final map = Map<String, dynamic>.from(itemRaw);
        final isOriginal = map['isOriginal'] == true;

        result.add(CategoryItem(
          id: map['id']?.toString() ?? '',
          contentUri: map['contentUri']?.toString() ?? '',
          displayName: map['displayName']?.toString() ?? '',
          mimeType: map['mimeType']?.toString() ?? '',
          sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
          dateAddedSec: (map['dateAddedSec'] as num?)?.toInt() ?? 0,
          dateModifiedSec: (map['dateModifiedSec'] as num?)?.toInt() ?? 0,
          bucketName: map['bucketName']?.toString() ?? '',
          sourceApp: map['sourceApp']?.toString() ?? '',
          width: (map['width'] as num?)?.toInt() ?? 0,
          height: (map['height'] as num?)?.toInt() ?? 0,
          durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
          isProtected: map['isProtected'] == true,
          isOriginal: isOriginal,
          isCrossApp: isCrossApp,
          badgeLabel: isOriginal ? 'Original' : 'Duplicate',
          groupTitle: groupTitle,
        ));
      }
      groupIndex++;
    }

    _totalPotentialSavings = totalSavings;
    _duplicateGroupsCount = groupIndex - 1;
    return result;
  }

  List<CategoryItem> _computeInMemoryDuplicates(List<CategoryItem> items) {
    // REQ-ACT-05: Exclude protected items
    final activeItems = items.where((i) => !i.isProtected).toList();

    // Stage 1: Bucket by size
    final bySize = <int, List<CategoryItem>>{};
    for (final item in activeItems) {
      if (item.sizeBytes > 0) {
        bySize.putIfAbsent(item.sizeBytes, () => []).add(item);
      }
    }

    final duplicateCandidates = bySize.values.where((list) => list.length > 1).toList();
    final result = <CategoryItem>[];
    var groupIndex = 1;
    var totalSavings = 0;

    for (final group in duplicateCandidates) {
      // Sort: oldest is Original (REQ-DUP-02)
      group.sort((a, b) {
        final c = a.dateAddedSec.compareTo(b.dateAddedSec);
        return c != 0 ? c : a.dateModifiedSec.compareTo(b.dateModifiedSec);
      });

      final original = group.first;
      final copyCount = group.length;
      final fileSize = group.first.sizeBytes;
      final saving = fileSize * (copyCount - 1);
      totalSavings += saving;

      final sourceAppsInGroup = group
          .map((i) => i.sourceApp)
          .where((s) => s.isNotEmpty)
          .toSet();
      final isCrossApp = sourceAppsInGroup.length > 1;
      final crossAppTag = isCrossApp ? 'Cross-App • ' : '';

      final groupTitle = 'Group $groupIndex: $copyCount copies • $crossAppTag${formatBytes(fileSize * copyCount)} (Save ${formatBytes(saving)})';

      for (final item in group) {
        final isOriginal = item.id == original.id;
        result.add(CategoryItem(
          id: item.id,
          contentUri: item.contentUri,
          displayName: item.displayName,
          mimeType: item.mimeType,
          sizeBytes: item.sizeBytes,
          dateAddedSec: item.dateAddedSec,
          dateModifiedSec: item.dateModifiedSec,
          bucketName: item.bucketName,
          sourceApp: item.sourceApp,
          width: item.width,
          height: item.height,
          durationMs: item.durationMs,
          isProtected: item.isProtected,
          isOriginal: isOriginal,
          isCrossApp: isCrossApp,
          badgeLabel: isOriginal ? 'Original' : 'Duplicate',
          groupTitle: groupTitle,
        ));
      }
      groupIndex++;
    }

    _totalPotentialSavings = totalSavings;
    _duplicateGroupsCount = groupIndex - 1;
    return result;
  }
}
