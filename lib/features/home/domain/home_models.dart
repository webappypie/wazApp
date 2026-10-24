// lib/features/home/domain/home_models.dart
//
// Pure domain models for the Home dashboard.
// All formulas are exact implementations of PRD §8 — no approximations.
// P-03: no fake data, no inflated numbers, no invented scores.

import 'dart:math' as math;

// ---------------------------------------------------------------------------
// Component label enum (PRD §8.1)
// ---------------------------------------------------------------------------

enum HealthLabel {
  good,     // ratio < 0.05
  moderate, // ratio < 0.15
  high;     // ratio >= 0.15

  static HealthLabel fromRatio(double ratio) {
    if (ratio < 0.05) return HealthLabel.good;
    if (ratio < 0.15) return HealthLabel.moderate;
    return HealthLabel.high;
  }

  String get displayName {
    return switch (this) {
      HealthLabel.good     => 'Good',
      HealthLabel.moderate => 'Moderate',
      HealthLabel.high     => 'High',
    };
  }
}

// ---------------------------------------------------------------------------
// Health score inputs (one per component — PRD §8.1)
// ---------------------------------------------------------------------------

/// Raw byte counts needed to compute the Media Health score.
/// Each field that isn't yet available (v2 categories) defaults to 0.
/// The formula redistributes weight proportionally for unimplemented categories
/// (PRD §8.1: "Categories not yet implemented contribute 0 and their weight
/// is redistributed proportionally").
class HealthScoreInputs {
  const HealthScoreInputs({
    required this.totalBytes,
    this.duplicateBytes      = 0,
    this.largeVideoBytesOver100MB = 0,
    this.bytesOlderThan1y   = 0,
    this.screenshotBytes     = 0,
    this.blurryBytes         = 0,
    this.likelyGreetingBytes = 0,
  });

  final int totalBytes;
  final int duplicateBytes;
  final int largeVideoBytesOver100MB;
  final int bytesOlderThan1y;
  final int screenshotBytes;
  final int blurryBytes;
  final int likelyGreetingBytes;

  static const HealthScoreInputs empty = HealthScoreInputs(totalBytes: 0);
}

// ---------------------------------------------------------------------------
// Health score component breakdown
// ---------------------------------------------------------------------------

class HealthScoreComponent {
  const HealthScoreComponent({
    required this.label,
    required this.ratio,
    required this.deduction,
    required this.healthLabel,
  });

  /// Human-readable name shown in the breakdown sheet.
  final String label;

  /// ratio = component_bytes / total_bytes  (clamped 0.0–1.0)
  final double ratio;

  /// Points deducted from 100 by this component.
  final double deduction;

  final HealthLabel healthLabel;

  String get ratioPercent => '${(ratio * 100).toStringAsFixed(1)}%';
}

// ---------------------------------------------------------------------------
// Health score result (PRD §8.1)
// ---------------------------------------------------------------------------

class HealthScoreResult {
  const HealthScoreResult({
    required this.score,
    required this.components,
  });

  /// Final score 0–100.
  final int score;

  /// One entry per component for the breakdown sheet (REQ-HOM-02).
  final List<HealthScoreComponent> components;

  /// Computes the Media Health score from raw byte inputs.
  /// Implements PRD §8.1 exactly — do not change without updating the PRD.
  ///
  /// ```
  /// duplicate_ratio   = duplicate_bytes / total_bytes
  /// large_video_ratio = bytes_in_videos_over_100MB / total_bytes
  /// old_ratio         = bytes_older_than_1y / total_bytes
  /// clutter_ratio     = (screenshot + blurry + likely_greeting) / total_bytes
  ///
  /// score = 100
  ///       - min(30, duplicate_ratio   * 100)
  ///       - min(25, large_video_ratio * 60)
  ///       - min(25, old_ratio         * 50)
  ///       - min(20, clutter_ratio     * 80)
  ///
  /// score = clamp(score, 0, 100)
  /// ```
  factory HealthScoreResult.compute(HealthScoreInputs inputs) {
    if (inputs.totalBytes == 0) {
      return const HealthScoreResult(score: 100, components: []);
    }

    final total = inputs.totalBytes.toDouble();

    final dupRatio    = (inputs.duplicateBytes / total).clamp(0.0, 1.0);
    final vidRatio    = (inputs.largeVideoBytesOver100MB / total).clamp(0.0, 1.0);
    final oldRatio    = (inputs.bytesOlderThan1y / total).clamp(0.0, 1.0);
    final clutterBytes = inputs.screenshotBytes + inputs.blurryBytes + inputs.likelyGreetingBytes;
    final clutterRatio = (clutterBytes / total).clamp(0.0, 1.0);

    final dupDed     = math.min(30.0, dupRatio    * 100.0);
    final vidDed     = math.min(25.0, vidRatio    * 60.0);
    final oldDed     = math.min(25.0, oldRatio    * 50.0);
    final clutterDed = math.min(20.0, clutterRatio * 80.0);

    final raw   = 100.0 - dupDed - vidDed - oldDed - clutterDed;
    final score = raw.clamp(0.0, 100.0).round();

    return HealthScoreResult(
      score: score,
      components: [
        HealthScoreComponent(
          label: 'Duplicate files',
          ratio: dupRatio,
          deduction: dupDed,
          healthLabel: HealthLabel.fromRatio(dupRatio),
        ),
        HealthScoreComponent(
          label: 'Large videos (100 MB+)',
          ratio: vidRatio,
          deduction: vidDed,
          healthLabel: HealthLabel.fromRatio(vidRatio),
        ),
        HealthScoreComponent(
          label: 'Old media (1 year+)',
          ratio: oldRatio,
          deduction: oldDed,
          healthLabel: HealthLabel.fromRatio(oldRatio),
        ),
        HealthScoreComponent(
          label: 'Clutter (screenshots, blurry, greetings)',
          ratio: clutterRatio,
          deduction: clutterDed,
          healthLabel: HealthLabel.fromRatio(clutterRatio),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recoverable space (PRD §8.3)
// ---------------------------------------------------------------------------

/// A single file eligible for recovery, tagged with its category.
/// Used to enforce the "each file counted once" rule (§8.3).
class RecoverableFile {
  const RecoverableFile({
    required this.contentUri,
    required this.sizeBytes,
    required this.category,
  });

  final String contentUri;
  final int sizeBytes;
  final RecoverableCategory category;
}

enum RecoverableCategory {
  duplicate,
  // similarGroupNonBest,   // v2
  // blurryHighConfidence,  // v2
  // estimatedCompression,  // v2 — must be labelled "estimated"
}

/// Computes recoverable bytes, enforcing the "each file counted exactly once,
/// using its highest-confidence category" rule (PRD §8.3).
///
/// Protected items are always excluded (passed in as [protectedUris]).
///
/// Ship blocker: double-counting a file across categories is forbidden.
/// Unit tests must cover this.
class RecoverableSpaceResult {
  const RecoverableSpaceResult({
    required this.totalRecoverableBytes,
    required this.byCategory,
  });

  final int totalRecoverableBytes;
  final Map<RecoverableCategory, int> byCategory;

  factory RecoverableSpaceResult.compute({
    required List<RecoverableFile> candidates,
    required Set<String> protectedUris,
  }) {
    final seen    = <String>{};
    final totals  = <RecoverableCategory, int>{};
    var   grandTotal = 0;

    // Priority order mirrors PRD §8.3 category listing.
    // For v1 only duplicate is implemented.
    const priority = [
      RecoverableCategory.duplicate,
    ];

    // Sort candidates by priority so the highest-confidence category wins.
    final sorted = List<RecoverableFile>.from(candidates)
      ..sort((a, b) =>
          priority.indexOf(a.category) - priority.indexOf(b.category));

    for (final f in sorted) {
      // Skip protected items (P-02, REQ-ACT-05).
      if (protectedUris.contains(f.contentUri)) continue;
      // Each file counted exactly once (§8.3 — ship blocker).
      if (seen.contains(f.contentUri)) continue;
      seen.add(f.contentUri);
      totals[f.category] = (totals[f.category] ?? 0) + f.sizeBytes;
      grandTotal += f.sizeBytes;
    }

    return RecoverableSpaceResult(
      totalRecoverableBytes: grandTotal,
      byCategory: totals,
    );
  }
}

// ---------------------------------------------------------------------------
// Cleanup opportunity card model
// ---------------------------------------------------------------------------

/// Data for one cleanup opportunity card on the Home screen (REQ-HOM-03).
class OpportunityCard {
  const OpportunityCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.fileCount,
    required this.totalBytes,
    required this.routePath,
    this.isAvailable = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final int iconData; // IconData.codePoint — keeps model dependency-free
  final int fileCount;
  final int totalBytes;
  final String routePath;

  /// False when the category hasn't been scanned yet or returned 0 results.
  final bool isAvailable;

  String get formattedSize => _formatBytes(totalBytes);
}

// ---------------------------------------------------------------------------
// Recent activity entry
// ---------------------------------------------------------------------------

/// One entry in the Recent Activity section (REQ-HOM-04).
class RecentActivityEntry {
  const RecentActivityEntry({
    required this.actionLabel,
    required this.filesCount,
    required this.bytesRecovered,
    required this.timestamp,
  });

  final String actionLabel;
  final int filesCount;
  final int bytesRecovered;
  final DateTime timestamp;

  String get formattedBytes => _formatBytes(bytesRecovered);
}

// ---------------------------------------------------------------------------
// Source breakdown model (WhatsApp vs WhatsApp Business)
// ---------------------------------------------------------------------------

class SourceBreakdown {
  const SourceBreakdown({
    required this.whatsAppBytes,
    required this.whatsAppCount,
    required this.whatsAppPotentialCleanupBytes,
    required this.businessBytes,
    required this.businessCount,
    required this.businessPotentialCleanupBytes,
  });

  final int whatsAppBytes;
  final int whatsAppCount;
  final int whatsAppPotentialCleanupBytes;

  final int businessBytes;
  final int businessCount;
  final int businessPotentialCleanupBytes;

  int get totalBytes => whatsAppBytes + businessBytes;
  int get totalCount => whatsAppCount + businessCount;
  int get totalPotentialCleanupBytes =>
      whatsAppPotentialCleanupBytes + businessPotentialCleanupBytes;

  double get whatsAppPercent =>
      totalBytes > 0 ? (whatsAppBytes / totalBytes) * 100 : 0.0;
  double get businessPercent =>
      totalBytes > 0 ? (businessBytes / totalBytes) * 100 : 0.0;

  String get formattedWhatsAppBytes => _formatBytes(whatsAppBytes);
  String get formattedBusinessBytes => _formatBytes(businessBytes);
  String get formattedWhatsAppCleanup => _formatBytes(whatsAppPotentialCleanupBytes);
  String get formattedBusinessCleanup => _formatBytes(businessPotentialCleanupBytes);
  String get formattedTotalCleanup => _formatBytes(totalPotentialCleanupBytes);

  bool get hasBothSources => whatsAppBytes > 0 && businessBytes > 0;
  bool get hasBusinessMedia => businessBytes > 0 || businessCount > 0;
}

// ---------------------------------------------------------------------------
// Home dashboard summary — combines all sections
// ---------------------------------------------------------------------------

class HomeDashboard {
  const HomeDashboard({
    required this.totalIndexedBytes,
    required this.totalItemCount,
    required this.healthScore,
    required this.recoverable,
    required this.monthOverMonthDelta,
    required this.opportunities,
    required this.recentActivity,
    this.sourceBreakdown,
  });

  final int totalIndexedBytes;
  final int totalItemCount;
  final HealthScoreResult healthScore;
  final RecoverableSpaceResult recoverable;

  /// Positive = growth, negative = reduction. Null = not enough history.
  final int? monthOverMonthDelta;

  final List<OpportunityCard> opportunities;
  final List<RecentActivityEntry> recentActivity;
  final SourceBreakdown? sourceBreakdown;

  String get formattedTotal => _formatBytes(totalIndexedBytes);
  String get formattedRecoverable =>
      _formatBytes(recoverable.totalRecoverableBytes);

  HomeDashboard copyWith({
    int? totalIndexedBytes,
    int? totalItemCount,
    HealthScoreResult? healthScore,
    RecoverableSpaceResult? recoverable,
    int? monthOverMonthDelta,
    List<OpportunityCard>? opportunities,
    List<RecentActivityEntry>? recentActivity,
    SourceBreakdown? sourceBreakdown,
  }) {
    return HomeDashboard(
      totalIndexedBytes: totalIndexedBytes ?? this.totalIndexedBytes,
      totalItemCount: totalItemCount ?? this.totalItemCount,
      healthScore: healthScore ?? this.healthScore,
      recoverable: recoverable ?? this.recoverable,
      monthOverMonthDelta: monthOverMonthDelta ?? this.monthOverMonthDelta,
      opportunities: opportunities ?? this.opportunities,
      recentActivity: recentActivity ?? this.recentActivity,
      sourceBreakdown: sourceBreakdown ?? this.sourceBreakdown,
    );
  }

  static const empty = HomeDashboard(
    totalIndexedBytes: 0,
    totalItemCount: 0,
    healthScore: HealthScoreResult(score: 100, components: []),
    recoverable: RecoverableSpaceResult(totalRecoverableBytes: 0, byCategory: {}),
    monthOverMonthDelta: null,
    opportunities: [],
    recentActivity: [],
    sourceBreakdown: null,
  );
}

// ---------------------------------------------------------------------------
// Shared byte formatter
// ---------------------------------------------------------------------------

String _formatBytes(int bytes) {
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
