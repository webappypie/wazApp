// lib/features/clean/presentation/clean_screen.dart
//
// Clean tab — shows real scan progress (REQ-IDX-05) and, once indexed,
// a summary of what was found.
//
// Rules enforced here:
//   - REQ-IDX-05: progress bar driven by actual itemsProcessed/itemsTotal —
//     no interpolation, no fake percentage, monotonically non-decreasing.
//   - P-03: every number displayed traces to real data from the DB or formula.
//   - REQ-ADS-05: no ad adjacent to or on a scan-progress screen.
//   - REQ-ACT-02: Cancel button shown during scan; dismisses to idle state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../core/widgets/partial_access_banner.dart';
import '../../indexing/domain/indexing_models.dart';
import '../../indexing/presentation/indexing_providers.dart';

class CleanScreen extends ConsumerWidget {
  const CleanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(scanProgressProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Clean'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // REQ-ONB-05: persistent partial-access banner when limited.
          const PartialAccessBanner(),
          Expanded(
            child: progressAsync.when(
              data:    (p) => _CleanBody(progress: p),
              loading: () => const SkeletonListLoader(itemCount: 4),
              error:   (e, _) => ErrorState(
                message: 'Failed to load scan state.\n$e',
                onRetry: () => ref.invalidate(scanProgressProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — switches between idle, scanning, and results states
// ---------------------------------------------------------------------------

class _CleanBody extends ConsumerWidget {
  const _CleanBody({required this.progress});
  final ScanProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (progress.status) {
      ScanStatus.idle      => _IdleView(),
      ScanStatus.running   => _ScanProgressView(progress: progress),
      ScanStatus.paused    => _ScanProgressView(progress: progress, paused: true),
      ScanStatus.done      => _DoneView(progress: progress),
      ScanStatus.cancelled => _IdleView(wasCancelled: true),
      ScanStatus.error     => ErrorState(
          message: 'Scan failed: ${progress.error ?? "unknown error"}',
          onRetry: () => ref.read(indexingServiceProvider).startScan(),
        ),
    };
  }
}

// ---------------------------------------------------------------------------
// Idle — start scan CTA
// ---------------------------------------------------------------------------

class _IdleView extends ConsumerWidget {
  const _IdleView({this.wasCancelled = false});
  final bool wasCancelled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cleaning_services_outlined,
                size: 72, color: scheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              wasCancelled ? 'Scan cancelled' : 'Ready to clean',
              style: AppTextStyles.headlineSmall
                  .copyWith(color: scheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              wasCancelled
                  ? 'Your media was not changed. Tap below to start again.'
                  : 'Scan your WhatsApp media to find duplicates, large files '
                    'and old content you can safely remove.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search_rounded),
                label: const Text('Scan media'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  elevation: AppElevation.none,
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonRadius),
                ),
                onPressed: () =>
                    ref.read(indexingServiceProvider).startScan(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scanning — real progress (REQ-IDX-05)
// ---------------------------------------------------------------------------

class _ScanProgressView extends ConsumerWidget {
  const _ScanProgressView({required this.progress, this.paused = false});
  final ScanProgress progress;
  final bool paused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final pct    = progress.fraction;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),

          // Status label
          Row(
            children: [
              if (!paused)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                )
              else
                Icon(Icons.pause_circle_outline_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Text(
                paused ? 'Scan paused' : 'Scanning your media…',
                style: AppTextStyles.titleMedium
                    .copyWith(color: scheme.onSurface),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Real progress bar — fraction from actual counts, never interpolated
          Semantics(
            label: 'Scan progress: ${progress.itemsProcessed} of '
                '${progress.itemsTotal} items',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                  child: LinearProgressIndicator(
                    value: progress.itemsTotal > 0 ? pct : null,
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      // Actual counts — P-03: never fabricated
                      progress.itemsTotal > 0
                          ? '${progress.itemsProcessed} / ${progress.itemsTotal} items'
                          : '${progress.itemsProcessed} items…',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Text(
                      _formatBytes(progress.bytesProcessed),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Pause / Resume / Cancel controls
          Row(
            children: [
              OutlinedButton.icon(
                icon: Icon(
                  paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  size: 18,
                ),
                label: Text(paused ? 'Resume' : 'Pause'),
                onPressed: paused
                    ? () => ref.read(indexingServiceProvider).resume()
                    : () => ref.read(indexingServiceProvider).pause(),
              ),
              const SizedBox(width: AppSpacing.sm),
              // REQ-ADS-05: no ads adjacent to this screen
              OutlinedButton.icon(
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kColorDestructive,
                  side: BorderSide(color: kColorDestructive.withValues(alpha: 0.4)),
                ),
                onPressed: () => ref.read(indexingServiceProvider).cancel(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Done — summary of what was indexed
// ---------------------------------------------------------------------------

class _DoneView extends ConsumerWidget {
  const _DoneView({required this.progress});
  final ScanProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme     = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(indexStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // Summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: AppRadius.cardRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        color: kColorSuccess, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Scan complete',
                        style: AppTextStyles.titleMedium
                            .copyWith(color: scheme.onSurface)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                statsAsync.when(
                  data: (stats) => _StatRow(
                    label: 'WhatsApp media indexed',
                    value: '${stats.itemCount} items · ${stats.formattedBytes}',
                  ),
                  loading: () => const SizedBox(
                    height: 16,
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => const _StatRow(
                    label: 'WhatsApp media indexed',
                    value: '—',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Rescan CTA
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Re-scan'),
              onPressed: () => ref.read(indexingServiceProvider).startScan(),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Phase 5: View all indexed media category
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Browse All Indexed Media'),
                    onPressed: () => context.go(AppRoutes.allMedia),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Specific category breakdown coming in Phase 6',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
        Text(value,
            style: AppTextStyles.titleSmall.copyWith(color: scheme.onSurface)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Utilities
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
