// lib/features/indexing/data/real_indexing_repository.dart
//
// Real implementation of IndexingRepository.
// Bridges the Kotlin platform channel (MediaIndexer) → Drift DB → domain layer.
//
// Architecture (DEV_PROMPT §3): data layer — depends on core/services and DB.
// Nothing in presentation or domain imports this directly; go through the
// indexingRepositoryProvider in providers.dart.

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../domain/indexing_models.dart';
import '../domain/indexing_repository.dart';

const _methodChannel = MethodChannel('com.wapptidy/media_indexer');
const _eventChannel  = EventChannel('com.wapptidy/media_indexer_events');

class RealIndexingRepository implements IndexingRepository {
  RealIndexingRepository(this._db);

  final AppDatabase _db;

  // Tracks the current scan version so stale rows can be pruned at the end.
  int _currentScanVersion = 0;

  @override
  Stream<ScanProgress> startFullIndex({
    int sinceModifiedSec = 0,
    int generationSince = 0,
  }) async* {
    // Read the current scan version from DB and bump it.
    final state = await _db.readScanState();
    _currentScanVersion = state.currentScanVersion + 1;

    // Persist running state.
    await _db.updateScanState(ScanStateTableCompanion(
      status:             const Value('running'),
      currentScanVersion: Value(_currentScanVersion),
      itemsProcessed:     const Value(0),
      itemsTotal:         const Value(0),
      bytesProcessed:     const Value(0),
      startedAtMs:        Value(DateTime.now().millisecondsSinceEpoch),
      errorMessage:       const Value(null),
    ));

    // Tell Kotlin to start scanning.
    await _methodChannel.invokeMethod<void>('startIndex', {
      'sinceModifiedSec': sinceModifiedSec,
      'scanVersion':      _currentScanVersion,
      'generationSince':  generationSince,
    });

    // Stream events from Kotlin EventChannel.
    await for (final rawEvent in _eventChannel.receiveBroadcastStream()) {
      final event = Map<Object?, Object?>.from(rawEvent as Map);
      final status = event['status'] as String? ?? 'error';
      final itemsProcessed = (event['itemsProcessed'] as num?)?.toInt() ?? 0;
      final itemsTotal     = (event['itemsTotal'] as num?)?.toInt() ?? 0;
      final bytesProcessed = (event['bytesProcessed'] as num?)?.toInt() ?? 0;

      // Persist progress to DB (for crash recovery — REQ-IDX-04).
      await _db.updateScanState(ScanStateTableCompanion(
        status:         Value(status),
        itemsProcessed: Value(itemsProcessed),
        itemsTotal:     Value(itemsTotal),
        bytesProcessed: Value(bytesProcessed),
      ));

      // Insert batch into Drift if this is a progress event with items.
      if (status == 'progress') {
        final rawItems = event['items'] as List<Object?>? ?? [];
        if (rawItems.isNotEmpty) {
          final companions = rawItems
              .whereType<Map<Object?, Object?>>()
              .map((m) => _toCompanion(RawMediaItem.fromMap(m, _currentScanVersion)))
              .toList();
          await _db.upsertMediaItems(companions);
        }
      }

      // Build domain progress.
      final domainStatus = _parseScanStatus(status);
      final progress = ScanProgress(
        status:         domainStatus,
        itemsProcessed: itemsProcessed,
        itemsTotal:     itemsTotal,
        bytesProcessed: bytesProcessed,
        scanVersion:    _currentScanVersion,
        generation:     (event['generation'] as num?)?.toInt() ?? 0,
        error:          event['error'] as String?,
      );

      yield progress;

      if (progress.isTerminal) {
        if (domainStatus == ScanStatus.done) {
          // Prune stale rows (files deleted since last scan — REQ-IDX-07).
          await _db.deleteStaleItems(_currentScanVersion);

          // Persist final generation for next incremental check.
          await _db.updateScanState(ScanStateTableCompanion(
            status:            const Value('done'),
            lastSeenGeneration: Value(progress.generation),
          ));
        }
        break;
      }
    }
  }

  @override
  Future<void> pause() => _methodChannel.invokeMethod<void>('pause');

  @override
  Future<void> resume() => _methodChannel.invokeMethod<void>('resume');

  @override
  Future<void> cancel() async {
    await _methodChannel.invokeMethod<void>('cancel');
    await _db.updateScanState(const ScanStateTableCompanion(
      status: Value('cancelled'),
    ));
  }

  @override
  Future<int> currentGeneration() async {
    final result = await _methodChannel.invokeMethod<Object>('currentGeneration');
    return (result as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> lastSavedGeneration() async {
    final state = await _db.readScanState();
    return state.lastSeenGeneration;
  }

  @override
  Future<ScanProgress> restoreScanState() async {
    final state = await _db.readScanState();
    return ScanProgress(
      status:         _parseScanStatus(state.status),
      itemsProcessed: state.itemsProcessed,
      itemsTotal:     state.itemsTotal,
      bytesProcessed: state.bytesProcessed,
      scanVersion:    state.currentScanVersion,
    );
  }

  @override
  Future<int> indexedItemCount() => _db.countAllItems();

  @override
  Future<int> indexedTotalBytes() => _db.sumAllBytes();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  MediaItemsCompanion _toCompanion(RawMediaItem r) => MediaItemsCompanion.insert(
        contentUri:      r.contentUri,
        mediaStoreId:    r.mediaStoreId,
        displayName:     r.displayName,
        mimeType:        r.mimeType,
        sizeBytes:       r.sizeBytes,
        dateAddedSec:    r.dateAddedSec,
        dateModifiedSec: r.dateModifiedSec,
        bucketName:      r.bucketName,
        sourceApp:       r.sourceApp,
        width:           Value(r.width),
        height:          Value(r.height),
        durationMs:      Value(r.durationMs),
        scanVersion:     r.scanVersion,
      );

  ScanStatus _parseScanStatus(String s) {
    return switch (s) {
      'running'   => ScanStatus.running,
      'paused'    => ScanStatus.paused,
      'cancelled' => ScanStatus.cancelled,
      'done'      => ScanStatus.done,
      'error'     => ScanStatus.error,
      _           => ScanStatus.idle,
    };
  }
}
