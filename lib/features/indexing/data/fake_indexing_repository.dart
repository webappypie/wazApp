// lib/features/indexing/data/fake_indexing_repository.dart
//
// Fake IndexingRepository for tests.
// Emits a configurable stream of ScanProgress events — no platform channel,
// no Drift DB, no file system access.

import 'dart:async';

import '../domain/indexing_models.dart';
import '../domain/indexing_repository.dart';

class FakeIndexingRepository implements IndexingRepository {
  /// Events to emit when startFullIndex() is called. Configurable per test.
  List<ScanProgress> scanEvents = [
    const ScanProgress(
      status: ScanStatus.running,
      itemsProcessed: 50,
      itemsTotal: 200,
      bytesProcessed: 5 * 1024 * 1024,
    ),
    const ScanProgress(
      status: ScanStatus.running,
      itemsProcessed: 150,
      itemsTotal: 200,
      bytesProcessed: 15 * 1024 * 1024,
    ),
    const ScanProgress(
      status: ScanStatus.done,
      itemsProcessed: 200,
      itemsTotal: 200,
      bytesProcessed: 20 * 1024 * 1024,
      generation: 42,
    ),
  ];

  /// Delay between emitted events (default: none for tests).
  Duration eventDelay = Duration.zero;

  bool pauseCalled   = false;
  bool resumeCalled  = false;
  bool cancelCalled  = false;
  int  _fakeGeneration = 42;
  int  _fakeLastGeneration = 0;
  int  _fakeCount = 200;
  int  _fakeBytes = 20 * 1024 * 1024;

  @override
  Stream<ScanProgress> startFullIndex({
    int sinceModifiedSec = 0,
    int generationSince = 0,
    List<String>? allowedSources,
  }) async* {
    for (final event in scanEvents) {
      if (eventDelay != Duration.zero) await Future<void>.delayed(eventDelay);
      yield event;
      if (event.isTerminal) break;
    }
  }

  @override
  Future<void> pause() async => pauseCalled = true;

  @override
  Future<void> resume() async => resumeCalled = true;

  @override
  Future<void> cancel() async => cancelCalled = true;

  @override
  Future<int> currentGeneration() async => _fakeGeneration;

  @override
  Future<int> lastSavedGeneration() async => _fakeLastGeneration;

  @override
  Future<ScanProgress> restoreScanState() async => const ScanProgress(
        status: ScanStatus.idle,
        itemsProcessed: 0,
        itemsTotal: 0,
        bytesProcessed: 0,
      );

  @override
  Future<int> indexedItemCount() async => _fakeCount;

  @override
  Future<int> indexedTotalBytes() async => _fakeBytes;

  void configure({
    int? generation,
    int? lastGeneration,
    int? count,
    int? bytes,
  }) {
    if (generation != null) _fakeGeneration = generation;
    if (lastGeneration != null) _fakeLastGeneration = lastGeneration;
    if (count != null) _fakeCount = count;
    if (bytes != null) _fakeBytes = bytes;
  }

  void reset() {
    pauseCalled   = false;
    resumeCalled  = false;
    cancelCalled  = false;
  }
}
