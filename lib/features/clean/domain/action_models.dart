// lib/features/clean/domain/action_models.dart
//
// Domain models for Phase 7 file operations and cleanup reporting
// (REQ-ACT-01 to REQ-ACT-07, REQ-BIN-01 to REQ-BIN-05).

enum ActionType {
  trash,
  deletePermanently,
  move,
  copy,
  archive,
  protect,
  unprotect,
}

class FileActionResult {
  const FileActionResult({
    this.succeededIds = const [],
    this.failedIds = const [],
    this.skippedIds = const [],
    this.failureReasons = const {},
    this.totalBytesProcessed = 0,
  });

  final List<String> succeededIds;
  final List<String> failedIds;
  final List<String> skippedIds;
  final Map<String, String> failureReasons;
  final int totalBytesProcessed;

  bool get isSuccess => failedIds.isEmpty;
  int get succeededCount => succeededIds.length;
  int get failedCount => failedIds.length;
  int get skippedCount => skippedIds.length;

  factory FileActionResult.fromMap(Map<String, dynamic> map) {
    return FileActionResult(
      succeededIds: (map['succeededIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      failedIds: (map['failedIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      skippedIds: (map['skippedIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      failureReasons: (map['failureReasons'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          {},
      totalBytesProcessed: (map['totalBytesProcessed'] as num?)?.toInt() ?? 0,
    );
  }
}

class CleanupSessionSummary {
  const CleanupSessionSummary({
    this.recoveredBytes = 0,
    this.reviewedCount = 0,
    this.removedCount = 0,
    this.movedCount = 0,
    this.protectedCount = 0,
  });

  final int recoveredBytes;
  final int reviewedCount;
  final int removedCount;
  final int movedCount;
  final int protectedCount;
}
