// lib/core/database/tables/scan_state_table.dart
//
// Drift table for durable scan state (REQ-IDX-04).
// A single row (id=1) records where the current or last scan stopped.
// If the app is killed mid-scan, the next launch reads this row and resumes
// from the last committed cursor position.

import 'package:drift/drift.dart';

/// Scan state enumeration — stored as text.
/// Values: 'idle' | 'running' | 'paused' | 'cancelled' | 'done' | 'error'
class ScanStateTable extends Table {
  @override
  String get tableName => 'scan_state';

  /// Always 1 — singleton row.
  IntColumn get id => integer()();

  /// Current state: idle | running | paused | cancelled | done | error
  TextColumn get status => text().withDefault(const Constant('idle'))();

  /// The scan version number for this pass (matches MediaItems.scanVersion).
  IntColumn get currentScanVersion => integer().withDefault(const Constant(0))();

  /// Items processed so far in the current scan (monotonically non-decreasing).
  IntColumn get itemsProcessed => integer().withDefault(const Constant(0))();

  /// Total items discovered so far (updated incrementally as we learn the count).
  IntColumn get itemsTotal => integer().withDefault(const Constant(0))();

  /// Bytes processed so far.
  IntColumn get bytesProcessed => integer().withDefault(const Constant(0))();

  /// Last MediaStore generation ID seen (for incremental rescan — REQ-IDX-03).
  IntColumn get lastSeenGeneration => integer().withDefault(const Constant(0))();

  /// dateModifiedSec of the last item we successfully processed (cursor).
  /// A resumed scan queries WHERE dateModifiedSec >= this value.
  IntColumn get lastModifiedCursor => integer().withDefault(const Constant(0))();

  /// Unix timestamp (ms) when this scan started.
  IntColumn get startedAtMs => integer().withDefault(const Constant(0))();

  /// Error message if status == 'error'. Null otherwise.
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
