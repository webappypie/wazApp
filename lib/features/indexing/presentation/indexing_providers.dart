// lib/features/indexing/presentation/indexing_providers.dart
//
// Riverpod providers for the indexing engine.
// All UI and domain code reads from here — never imports the repository directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/real_indexing_repository.dart';
import '../domain/indexing_models.dart';
import '../domain/indexing_repository.dart';
import 'indexing_service.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// The indexing repository provider.
/// Phase 3: uses RealIndexingRepository (platform channel + Drift).
/// Tests: override with FakeIndexingRepository.
final indexingRepositoryProvider = Provider<IndexingRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return RealIndexingRepository(db);
});

// ---------------------------------------------------------------------------
// Scan progress stream
// ---------------------------------------------------------------------------

/// Exposes the live scan progress as an `AsyncValue<ScanProgress>`.
/// Starts as idle (restored from DB), becomes active once a scan starts.
final scanProgressProvider =
    StreamProvider.autoDispose<ScanProgress>((ref) async* {
  final repo = ref.watch(indexingRepositoryProvider);

  // On first listen, restore the last known state from DB.
  final restored = await repo.restoreScanState();
  yield restored;

  // IndexingService drives subsequent events via its controller.
  final svc = ref.watch(indexingServiceProvider);
  yield* svc.progressStream;
});

// ---------------------------------------------------------------------------
// Indexing service
// ---------------------------------------------------------------------------

final indexingServiceProvider = Provider<IndexingService>((ref) {
  final repo = ref.watch(indexingRepositoryProvider);
  final svc  = IndexingService(repo);
  ref.onDispose(svc.dispose);
  return svc;
});

// ---------------------------------------------------------------------------
// Index stats (item count + total bytes) — polled after scan completes
// ---------------------------------------------------------------------------

/// Summary stats read from the DB. Refreshed on every scan completion.
final indexStatsProvider = FutureProvider.autoDispose<IndexStats>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(indexingRepositoryProvider);
  final count = await repo.indexedItemCount();
  final bytes = await repo.indexedTotalBytes();

  final waCount = await db.countAllItems(sourceApp: 'com.whatsapp');
  final waBytes = await db.sumAllBytes(sourceApp: 'com.whatsapp');
  final bizCount = await db.countAllItems(sourceApp: 'com.whatsapp.w4b');
  final bizBytes = await db.sumAllBytes(sourceApp: 'com.whatsapp.w4b');

  return IndexStats(
    itemCount: count,
    totalBytes: bytes,
    whatsAppItemCount: waCount,
    whatsAppTotalBytes: waBytes,
    businessItemCount: bizCount,
    businessTotalBytes: bizBytes,
  );
});

// ---------------------------------------------------------------------------
// Domain model for stats
// ---------------------------------------------------------------------------

class IndexStats {
  const IndexStats({
    required this.itemCount,
    required this.totalBytes,
    this.whatsAppItemCount = 0,
    this.whatsAppTotalBytes = 0,
    this.businessItemCount = 0,
    this.businessTotalBytes = 0,
  });

  final int itemCount;
  final int totalBytes;
  final int whatsAppItemCount;
  final int whatsAppTotalBytes;
  final int businessItemCount;
  final int businessTotalBytes;

  String get formattedBytes => _formatBytes(totalBytes);
  String get formattedWhatsAppBytes => _formatBytes(whatsAppTotalBytes);
  String get formattedBusinessBytes => _formatBytes(businessTotalBytes);

  bool get hasBusinessMedia => businessItemCount > 0;
  bool get hasWhatsAppMedia => whatsAppItemCount > 0;
  bool get hasBothSources => hasBusinessMedia && hasWhatsAppMedia;

  static String _formatBytes(int bytes) {
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
}
