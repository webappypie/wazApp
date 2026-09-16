// lib/features/home/data/fake_home_repository.dart
//
// Fake HomeRepository for tests and pre-Phase 5 category data.
// Returns configurable HomeDashboard — no Drift, no platform channel.

import '../domain/home_models.dart';
import '../domain/home_repository.dart';

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({HomeDashboard? dashboard})
      : _dashboard = dashboard ?? _defaultDashboard;

  HomeDashboard _dashboard;
  final List<RecentActivityEntry> _activity = [];

  static final _defaultDashboard = HomeDashboard(
    totalIndexedBytes: 4 * 1024 * 1024 * 1024, // 4 GB
    totalItemCount: 3_842,
    healthScore: HealthScoreResult.compute(
      HealthScoreInputs(
        totalBytes:               4 * 1024 * 1024 * 1024,
        duplicateBytes:           512 * 1024 * 1024,
        largeVideoBytesOver100MB: 1024 * 1024 * 1024,
        bytesOlderThan1y:         800 * 1024 * 1024,
        screenshotBytes:          200 * 1024 * 1024,
      ),
    ),
    recoverable: RecoverableSpaceResult.compute(
      candidates: [
        const RecoverableFile(
          contentUri: 'content://media/1',
          sizeBytes:  512 * 1024 * 1024,
          category:   RecoverableCategory.duplicate,
        ),
      ],
      protectedUris: {},
    ),
    monthOverMonthDelta: 180 * 1024 * 1024, // +180 MB this month
    opportunities: [
      const OpportunityCard(
        id:        'duplicates',
        title:     'Exact Duplicates',
        subtitle:  'Identical files taking up space',
        iconData:  0xe3b3, // Icons.copy_all_rounded codepoint
        fileCount: 241,
        totalBytes: 512 * 1024 * 1024,
        routePath: '/clean/duplicates',
      ),
      const OpportunityCard(
        id:        'large_videos',
        title:     'Large Videos',
        subtitle:  'Videos over 100 MB',
        iconData:  0xe02c, // Icons.video_library_outlined codepoint
        fileCount: 18,
        totalBytes: 1024 * 1024 * 1024,
        routePath: '/clean/large-videos',
      ),
      const OpportunityCard(
        id:        'old_media',
        title:     'Old Media',
        subtitle:  'Files not opened in 1+ year',
        iconData:  0xe192, // Icons.history_rounded codepoint
        fileCount: 1_203,
        totalBytes: 800 * 1024 * 1024,
        routePath: '/clean/old-media',
      ),
      const OpportunityCard(
        id:        'screenshots',
        title:     'Screenshots',
        subtitle:  'Screenshots from all chats',
        iconData:  0xe3c8, // Icons.screenshot_monitor codepoint
        fileCount: 380,
        totalBytes: 200 * 1024 * 1024,
        routePath: '/clean/screenshots',
      ),
    ],
    recentActivity: [],
  );

  void setDashboard(HomeDashboard d) => _dashboard = d;

  @override
  Future<HomeDashboard> loadDashboard() async {
    // Merge the activity list so tests see recorded entries.
    return HomeDashboard(
      totalIndexedBytes:  _dashboard.totalIndexedBytes,
      totalItemCount:     _dashboard.totalItemCount,
      healthScore:        _dashboard.healthScore,
      recoverable:        _dashboard.recoverable,
      monthOverMonthDelta: _dashboard.monthOverMonthDelta,
      opportunities:      _dashboard.opportunities,
      recentActivity:     List.unmodifiable(_activity),
    );
  }

  @override
  Future<void> recordActivity({
    required String actionLabel,
    required int filesCount,
    required int bytesRecovered,
  }) async {
    _activity.insert(
      0,
      RecentActivityEntry(
        actionLabel:    actionLabel,
        filesCount:     filesCount,
        bytesRecovered: bytesRecovered,
        timestamp:      DateTime.now(),
      ),
    );
  }
}
