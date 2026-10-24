// lib/features/home/data/real_home_repository.dart
//
// Real HomeRepository — queries the Drift index to build HomeDashboard.
// Phase 4: computes health score and recoverable space from MediaItems data.
// Phase 6 will enrich this with category-specific byte queries.

import '../../../core/database/app_database.dart';
import '../domain/home_models.dart';
import '../domain/home_repository.dart';
import 'package:drift/drift.dart';

class RealHomeRepository implements HomeRepository {
  RealHomeRepository(this._db);

  final AppDatabase _db;

  @override
  Future<HomeDashboard> loadDashboard({String? sourceApp}) async {
    // --- Total stats (filtered by sourceApp if specified) ---
    final totalBytes = await _db.sumAllBytes(sourceApp: sourceApp);
    final totalCount = await _db.countAllItems(sourceApp: sourceApp);

    // --- Category byte queries from MediaItems ---
    final largeVideoBytes = await _queryLargeVideoBytes(sourceApp: sourceApp);

    final cutoff1y = DateTime.now()
        .subtract(const Duration(days: 365))
        .millisecondsSinceEpoch ~/
        1000;
    final oldBytes = await _queryOldMediaBytes(cutoff1y, sourceApp: sourceApp);
    final screenshotBytes = await _queryScreenshotBytes(sourceApp: sourceApp);

    const duplicateBytes = 0;

    final inputs = HealthScoreInputs(
      totalBytes:               totalBytes,
      duplicateBytes:           duplicateBytes,
      largeVideoBytesOver100MB: largeVideoBytes,
      bytesOlderThan1y:         oldBytes,
      screenshotBytes:          screenshotBytes,
    );

    final healthScore = HealthScoreResult.compute(inputs);

    final recoverableCandidates = await _buildRecoverableCandidates(sourceApp: sourceApp);
    final recoverable = RecoverableSpaceResult.compute(
      candidates: recoverableCandidates,
      protectedUris: const {},
    );

    // Month-over-month delta from date_added buckets.
    final momDelta = await _computeMonthOverMonthDelta(sourceApp: sourceApp);

    // Opportunity cards — real counts from DB.
    final opportunities = await _buildOpportunityCards(
      largeVideoBytesTotal: largeVideoBytes,
      oldBytesTotal: oldBytes,
      screenshotBytesTotal: screenshotBytes,
      sourceApp: sourceApp,
    );

    // Source breakdown (unfiltered by selection, to give comparative context)
    final waBytes = await _db.sumAllBytes(sourceApp: 'com.whatsapp');
    final waCount = await _db.countAllItems(sourceApp: 'com.whatsapp');
    final waCleanup = await _queryLargeVideoBytes(sourceApp: 'com.whatsapp');

    final bizBytes = await _db.sumAllBytes(sourceApp: 'com.whatsapp.w4b');
    final bizCount = await _db.countAllItems(sourceApp: 'com.whatsapp.w4b');
    final bizCleanup = await _queryLargeVideoBytes(sourceApp: 'com.whatsapp.w4b');

    final sourceBreakdown = SourceBreakdown(
      whatsAppBytes: waBytes,
      whatsAppCount: waCount,
      whatsAppPotentialCleanupBytes: waCleanup,
      businessBytes: bizBytes,
      businessCount: bizCount,
      businessPotentialCleanupBytes: bizCleanup,
    );

    return HomeDashboard(
      totalIndexedBytes:   totalBytes,
      totalItemCount:      totalCount,
      healthScore:         healthScore,
      recoverable:         recoverable,
      monthOverMonthDelta: momDelta,
      opportunities:       opportunities,
      recentActivity:      [],  // Phase 4: starts empty on fresh install (REQ-HOM-04)
      sourceBreakdown:     sourceBreakdown,
    );
  }

  @override
  Future<void> recordActivity({
    required String actionLabel,
    required int filesCount,
    required int bytesRecovered,
  }) async {
    // Phase 4: persisted to ScanStateTable notes or a future activity table.
    // For now this is a no-op; Phase 7 (Actions) will write a proper activity log.
  }

  // ---------------------------------------------------------------------------
  // Private DB queries
  // ---------------------------------------------------------------------------

  Expression<bool> _withSource(Expression<bool> condition, String? sourceApp) {
    if (sourceApp != null) {
      return condition & _db.mediaItems.sourceApp.equals(sourceApp);
    }
    return condition;
  }

  Future<int> _queryLargeVideoBytes({String? sourceApp}) async {
    const threshold = 100 * 1024 * 1024; // 100 MB
    final sumExpr = _db.mediaItems.sizeBytes.sum();
    final cond = _withSource(
      _db.mediaItems.mimeType.like('video/%') &
          _db.mediaItems.sizeBytes.isBiggerOrEqualValue(threshold),
      sourceApp,
    );
    final q = _db.selectOnly(_db.mediaItems)
      ..addColumns([sumExpr])
      ..where(cond);
    final row = await q.getSingle();
    return row.read(sumExpr) ?? 0;
  }

  Future<int> _queryOldMediaBytes(int cutoffSec, {String? sourceApp}) async {
    final sumExpr = _db.mediaItems.sizeBytes.sum();
    final cond = _withSource(
      _db.mediaItems.dateModifiedSec.isSmallerThanValue(cutoffSec),
      sourceApp,
    );
    final q = _db.selectOnly(_db.mediaItems)
      ..addColumns([sumExpr])
      ..where(cond);
    final row = await q.getSingle();
    return row.read(sumExpr) ?? 0;
  }

  Future<int> _queryScreenshotBytes({String? sourceApp}) async {
    final sumExpr = _db.mediaItems.sizeBytes.sum();
    final cond = _withSource(
      _db.mediaItems.bucketName.like('%Screenshot%'),
      sourceApp,
    );
    final q = _db.selectOnly(_db.mediaItems)
      ..addColumns([sumExpr])
      ..where(cond);
    final row = await q.getSingle();
    return row.read(sumExpr) ?? 0;
  }

  Future<List<RecoverableFile>> _buildRecoverableCandidates({String? sourceApp}) async {
    const threshold = 100 * 1024 * 1024;
    var cond = _db.mediaItems.mimeType.like('video/%') &
        _db.mediaItems.sizeBytes.isBiggerOrEqualValue(threshold) &
        _db.mediaItems.isProtected.equals(false);
    if (sourceApp != null) {
      cond = cond & _db.mediaItems.sourceApp.equals(sourceApp);
    }
    final q = _db.select(_db.mediaItems)..where((t) => cond);
    final rows = await q.get();
    return rows
        .map((r) => RecoverableFile(
              contentUri: r.contentUri,
              sizeBytes:  r.sizeBytes,
              category:   RecoverableCategory.duplicate,
            ))
        .toList();
  }

  Future<int?> _computeMonthOverMonthDelta({String? sourceApp}) async {
    final now      = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month);
    final lastMonthStart = DateTime(now.year, now.month - 1);

    final thisBytes = await _sumBytesAdded(
      from: thisMonthStart.millisecondsSinceEpoch ~/ 1000,
      to:   now.millisecondsSinceEpoch ~/ 1000,
      sourceApp: sourceApp,
    );
    final lastBytes = await _sumBytesAdded(
      from: lastMonthStart.millisecondsSinceEpoch ~/ 1000,
      to:   thisMonthStart.millisecondsSinceEpoch ~/ 1000,
      sourceApp: sourceApp,
    );

    if (thisBytes == 0 && lastBytes == 0) return null;
    return thisBytes - lastBytes;
  }

  Future<int> _sumBytesAdded({
    required int from,
    required int to,
    String? sourceApp,
  }) async {
    final sumExpr = _db.mediaItems.sizeBytes.sum();
    final cond = _withSource(
      _db.mediaItems.dateAddedSec.isBiggerOrEqualValue(from) &
          _db.mediaItems.dateAddedSec.isSmallerThanValue(to),
      sourceApp,
    );
    final q = _db.selectOnly(_db.mediaItems)
      ..addColumns([sumExpr])
      ..where(cond);
    final row = await q.getSingle();
    return row.read(sumExpr) ?? 0;
  }

  Future<List<OpportunityCard>> _buildOpportunityCards({
    required int largeVideoBytesTotal,
    required int oldBytesTotal,
    required int screenshotBytesTotal,
    String? sourceApp,
  }) async {
    final largeVideoCount = await _countWhere(
      _withSource(
        _db.mediaItems.mimeType.like('video/%') &
            _db.mediaItems.sizeBytes.isBiggerOrEqualValue(100 * 1024 * 1024),
        sourceApp,
      ),
    );
    final oldMediaCount = await _countWhere(
      _withSource(
        _db.mediaItems.dateModifiedSec.isSmallerThanValue(
          DateTime.now().subtract(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000,
        ),
        sourceApp,
      ),
    );
    final screenshotCount = await _countWhere(
      _withSource(
        _db.mediaItems.bucketName.like('%Screenshot%'),
        sourceApp,
      ),
    );

    final voiceNotesCount = await _countWhere(
      _withSource(_db.mediaItems.mimeType.like('audio/%'), sourceApp),
    );
    final voiceNotesBytes = await _sumWhere(
      _withSource(_db.mediaItems.mimeType.like('audio/%'), sourceApp),
    );

    final documentsCondition = _db.mediaItems.mimeType.like('application/%') |
        _db.mediaItems.mimeType.like('text/%') |
        (_db.mediaItems.mimeType.like('image/%').not() &
            _db.mediaItems.mimeType.like('video/%').not() &
            _db.mediaItems.mimeType.like('audio/%').not());
    final documentsCount = await _countWhere(
      _withSource(documentsCondition, sourceApp),
    );
    final documentsBytes = await _sumWhere(
      _withSource(documentsCondition, sourceApp),
    );

    return [
      if (largeVideoCount > 0)
        OpportunityCard(
          id:        'large_videos',
          title:     'Large Videos',
          subtitle:  '$largeVideoCount videos over 100 MB',
          iconData:  0xe1b4, // Icons.video_library_rounded codepoint
          fileCount: largeVideoCount,
          totalBytes: largeVideoBytesTotal,
          routePath: '/clean/large-videos',
        ),
      if (voiceNotesCount > 0)
        OpportunityCard(
          id:        'voice_notes',
          title:     'Voice Notes & Audio',
          subtitle:  '$voiceNotesCount voice notes and audio clips',
          iconData:  0xe3c9, // Icons.mic_none_rounded codepoint
          fileCount: voiceNotesCount,
          totalBytes: voiceNotesBytes,
          routePath: '/clean/voice-notes',
        ),
      if (documentsCount > 0)
        OpportunityCard(
          id:        'documents',
          title:     'Documents',
          subtitle:  '$documentsCount PDFs, docs and archives',
          iconData:  0xe1af, // Icons.description_outlined codepoint
          fileCount: documentsCount,
          totalBytes: documentsBytes,
          routePath: '/clean/documents',
        ),
      if (oldMediaCount > 0)
        OpportunityCard(
          id:        'old_media',
          title:     'Old Media',
          subtitle:  'Not modified in over a year',
          iconData:  0xe0e4, // Icons.history codepoint
          fileCount: oldMediaCount,
          totalBytes: oldBytesTotal,
          routePath: '/clean/old-media',
        ),
      if (screenshotCount > 0)
        OpportunityCard(
          id:        'screenshots',
          title:     'Screenshots',
          subtitle:  '$screenshotCount screenshots found',
          iconData:  0xe397, // Icons.screenshot_outlined codepoint
          fileCount: screenshotCount,
          totalBytes: screenshotBytesTotal,
          routePath: '/clean/screenshots',
        ),
    ];
  }

  Future<int> _sumWhere(Expression<bool> condition) async {
    final sumExpr = _db.mediaItems.sizeBytes.sum();
    final q = _db.selectOnly(_db.mediaItems)
      ..addColumns([sumExpr])
      ..where(condition);
    final row = await q.getSingle();
    return row.read(sumExpr) ?? 0;
  }

  Future<int> _countWhere(Expression<bool> condition) async {
    final countExpr = _db.mediaItems.id.count();
    final q = _db.selectOnly(_db.mediaItems)
      ..addColumns([countExpr])
      ..where(condition);
    final row = await q.getSingle();
    return row.read(countExpr) ?? 0;
  }
}
