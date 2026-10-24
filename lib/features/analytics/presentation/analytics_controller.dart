// lib/features/analytics/presentation/analytics_controller.dart
//
// Riverpod providers and state management for Storage Analytics (REQ-ANL-01..04).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AnalyticsRepository(database: db);
});

class SelectedTimeRangeNotifier extends Notifier<TimeRange> {
  @override
  TimeRange build() => TimeRange.thirtyDays;

  void setRange(TimeRange range) {
    state = range;
  }
}

final selectedTimeRangeProvider =
    NotifierProvider<SelectedTimeRangeNotifier, TimeRange>(
        SelectedTimeRangeNotifier.new);

final analyticsTrendsProvider = FutureProvider<AnalyticsTrends>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final range = ref.watch(selectedTimeRangeProvider);
  return repo.getTrends(range: range);
});

class BusinessInsights {
  const BusinessInsights({
    required this.totalBytes,
    required this.totalCount,
    required this.documentsCount,
    required this.documentsBytes,
    required this.invoicesCount,
    required this.invoicesBytes,
    required this.spreadsheetsCount,
    required this.spreadsheetsBytes,
    required this.catalogVideosBytes,
    required this.catalogVideosCount,
    required this.voiceNotesCount,
    required this.voiceNotesDurationSec,
  });

  final int totalBytes;
  final int totalCount;
  final int documentsCount;
  final int documentsBytes;
  final int invoicesCount;
  final int invoicesBytes;
  final int spreadsheetsCount;
  final int spreadsheetsBytes;
  final int catalogVideosBytes;
  final int catalogVideosCount;
  final int voiceNotesCount;
  final int voiceNotesDurationSec;

  bool get hasData => totalCount > 0;
}

final businessInsightsProvider = FutureProvider<BusinessInsights>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final bizItems = await (db.select(db.mediaItems)
        ..where((t) => t.sourceApp.equals('com.whatsapp.w4b')))
      .get();

  var totalBytes = 0;
  var docsCount = 0;
  var docsBytes = 0;
  var invoicesCount = 0;
  var invoicesBytes = 0;
  var spreadsheetsCount = 0;
  var spreadsheetsBytes = 0;
  var videosCount = 0;
  var videosBytes = 0;
  var voiceNotesCount = 0;
  var voiceNotesDurationSec = 0;

  for (final item in bizItems) {
    totalBytes += item.sizeBytes;
    final name = item.displayName.toLowerCase();
    final mime = item.mimeType.toLowerCase();

    final isInvoice = name.contains('invoice') ||
        name.contains('receipt') ||
        name.contains('bill') ||
        name.contains('order') ||
        name.contains('slip');

    if (isInvoice) {
      invoicesCount++;
      invoicesBytes += item.sizeBytes;
    }

    final isSheet = name.endsWith('.xls') ||
        name.endsWith('.xlsx') ||
        name.endsWith('.csv') ||
        mime.contains('sheet') ||
        mime.contains('excel');

    if (isSheet) {
      spreadsheetsCount++;
      spreadsheetsBytes += item.sizeBytes;
    }

    if (mime.startsWith('video/')) {
      videosCount++;
      videosBytes += item.sizeBytes;
    } else if (mime.startsWith('audio/')) {
      voiceNotesCount++;
      voiceNotesDurationSec += (item.durationMs ?? 0) ~/ 1000;
    } else if (mime.startsWith('application/') || mime.startsWith('text/')) {
      docsCount++;
      docsBytes += item.sizeBytes;
    }
  }

  return BusinessInsights(
    totalBytes: totalBytes,
    totalCount: bizItems.length,
    documentsCount: docsCount,
    documentsBytes: docsBytes,
    invoicesCount: invoicesCount,
    invoicesBytes: invoicesBytes,
    spreadsheetsCount: spreadsheetsCount,
    spreadsheetsBytes: spreadsheetsBytes,
    catalogVideosBytes: videosBytes,
    catalogVideosCount: videosCount,
    voiceNotesCount: voiceNotesCount,
    voiceNotesDurationSec: voiceNotesDurationSec,
  );
});
