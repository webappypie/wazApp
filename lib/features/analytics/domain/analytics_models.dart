// lib/features/analytics/domain/analytics_models.dart
//
// Pure domain models for Storage Growth Analytics (REQ-ANL-01 to REQ-ANL-04).
// All metrics trace directly to stored MediaStore data (P-03: no fabricated numbers).

/// Supported time ranges for storage trends (REQ-ANL-03).
/// PRD §11.3: 7D & 30D are free tier; 6M & All-time are Premium.
enum TimeRange {
  sevenDays('7D', '7 Days', 7, false),
  thirtyDays('30D', '30 Days', 30, false),
  sixMonths('6M', '6 Months', 180, true),
  allTime('All', 'All Time', null, true);

  const TimeRange(this.shortLabel, this.fullLabel, this.days, this.isPremiumOnly);

  final String shortLabel;
  final String fullLabel;
  final int? days;
  final bool isPremiumOnly;
}

/// A single daily storage snapshot record (REQ-ANL-01).
class StorageSnapshotPoint {
  const StorageSnapshotPoint({
    required this.dateEpochDay,
    required this.date,
    required this.totalBytes,
    this.imageBytes = 0,
    this.videoBytes = 0,
    this.audioBytes = 0,
    this.documentBytes = 0,
    this.duplicateBytes = 0,
    this.potentialCleanupBytes = 0,
    this.spaceRecoveredBytes = 0,
  });

  final int dateEpochDay;
  final DateTime date;
  final int totalBytes;
  final int imageBytes;
  final int videoBytes;
  final int audioBytes;
  final int documentBytes;
  final int duplicateBytes;
  final int potentialCleanupBytes;
  final int spaceRecoveredBytes;

  static StorageSnapshotPoint fromRow(Map<String, dynamic> data) {
    final epochDay = data['date_epoch_day'] as int;
    final date = DateTime.fromMillisecondsSinceEpoch(epochDay * 86400 * 1000, isUtc: true);

    return StorageSnapshotPoint(
      dateEpochDay: epochDay,
      date: date,
      totalBytes: data['total_bytes'] as int,
      imageBytes: (data['image_bytes'] as int?) ?? 0,
      videoBytes: (data['video_bytes'] as int?) ?? 0,
      audioBytes: (data['audio_bytes'] as int?) ?? 0,
      documentBytes: (data['document_bytes'] as int?) ?? 0,
      duplicateBytes: (data['duplicate_bytes'] as int?) ?? 0,
      potentialCleanupBytes: (data['potential_cleanup_bytes'] as int?) ?? 0,
      spaceRecoveredBytes: (data['space_recovered_bytes'] as int?) ?? 0,
    );
  }
}

/// Media category item for breakdown display.
class MediaCategoryBreakdownItem {
  const MediaCategoryBreakdownItem({
    required this.categoryName,
    required this.sizeBytes,
    required this.ratio,
  });

  final String categoryName;
  final int sizeBytes;
  final double ratio;

  String get percentageLabel => '${(ratio * 100).toStringAsFixed(1)}%';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaCategoryBreakdownItem &&
          runtimeType == other.runtimeType &&
          categoryName == other.categoryName &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => categoryName.hashCode ^ sizeBytes.hashCode;
}

/// Proportion breakdown across media types (REQ-ANL-03).
class MediaTypeBreakdown {
  const MediaTypeBreakdown({
    required this.imageBytes,
    required this.videoBytes,
    required this.audioBytes,
    required this.documentBytes,
    required this.totalBytes,
  });

  final int imageBytes;
  final int videoBytes;
  final int audioBytes;
  final int documentBytes;
  final int totalBytes;

  double get imageRatio => totalBytes > 0 ? (imageBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
  double get videoRatio => totalBytes > 0 ? (videoBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
  double get audioRatio => totalBytes > 0 ? (audioBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
  double get documentRatio => totalBytes > 0 ? (documentBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  List<MediaCategoryBreakdownItem> get rankedCategories {
    final list = [
      MediaCategoryBreakdownItem(categoryName: 'Videos', sizeBytes: videoBytes, ratio: videoRatio),
      MediaCategoryBreakdownItem(categoryName: 'Images', sizeBytes: imageBytes, ratio: imageRatio),
      MediaCategoryBreakdownItem(categoryName: 'Audio', sizeBytes: audioBytes, ratio: audioRatio),
      MediaCategoryBreakdownItem(categoryName: 'Documents', sizeBytes: documentBytes, ratio: documentRatio),
    ];
    list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    return list;
  }

  MediaCategoryBreakdownItem get largestContributor => rankedCategories.first;
}

/// Aggregated trend metrics for a selected time range (REQ-ANL-03, REQ-ANL-04).
class AnalyticsTrends {
  const AnalyticsTrends({
    required this.range,
    required this.snapshots,
    required this.currentTotalBytes,
    required this.netGrowthBytes,
    required this.netGrowthPercentage,
    required this.dailyAverageBytes,
    required this.breakdown,
    this.isBackfilled = false,
  });

  final TimeRange range;
  final List<StorageSnapshotPoint> snapshots;
  final int currentTotalBytes;
  final int netGrowthBytes;
  final double netGrowthPercentage;
  final int dailyAverageBytes;
  final MediaTypeBreakdown breakdown;
  final bool isBackfilled;

  factory AnalyticsTrends.compute({
    required TimeRange range,
    required List<StorageSnapshotPoint> snapshots,
    bool isBackfilled = false,
  }) {
    if (snapshots.isEmpty) {
      return AnalyticsTrends(
        range: range,
        snapshots: const [],
        currentTotalBytes: 0,
        netGrowthBytes: 0,
        netGrowthPercentage: 0.0,
        dailyAverageBytes: 0,
        breakdown: const MediaTypeBreakdown(
          imageBytes: 0,
          videoBytes: 0,
          audioBytes: 0,
          documentBytes: 0,
          totalBytes: 0,
        ),
        isBackfilled: isBackfilled,
      );
    }

    final first = snapshots.first;
    final last = snapshots.last;

    final currentTotal = last.totalBytes;
    final netGrowth = currentTotal - first.totalBytes;
    final growthPct = first.totalBytes > 0
        ? (netGrowth / first.totalBytes) * 100.0
        : (netGrowth > 0 ? 100.0 : 0.0);

    final daysCount = (last.dateEpochDay - first.dateEpochDay).abs() + 1;
    final dailyAvg = daysCount > 0 ? (netGrowth / daysCount).round() : 0;

    final breakdown = MediaTypeBreakdown(
      imageBytes: last.imageBytes,
      videoBytes: last.videoBytes,
      audioBytes: last.audioBytes,
      documentBytes: last.documentBytes,
      totalBytes: last.totalBytes,
    );

    return AnalyticsTrends(
      range: range,
      snapshots: snapshots,
      currentTotalBytes: currentTotal,
      netGrowthBytes: netGrowth,
      netGrowthPercentage: growthPct,
      dailyAverageBytes: dailyAvg,
      breakdown: breakdown,
      isBackfilled: isBackfilled,
    );
  }
}
