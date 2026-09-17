// lib/features/backup/presentation/backup_screen.dart
//
// Google Drive Cloud Backup Screen (REQ-BAK-01..03, P-01..03).
//
// REQ-BAK-01: drive.file scope only (non-sensitive, privacy-first).
// REQ-BAK-02: Items, total size, live progress, completed, failed, retry.
// REQ-BAK-03: Never delete local originals after upload. CTA reads "Review originals".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/services/backup/cloud_backup_service.dart';
import '../../clean/domain/category_models.dart';
import '../data/backup_repository.dart';
import 'backup_controller.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final progress = state.progress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive Backup'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. Google Drive Account & Scope Card (REQ-BAK-01)
          _buildAccountCard(context, ref, state, scheme),

          const SizedBox(height: AppSpacing.md),

          // 2. Active Upload Progress Card (REQ-BAK-02)
          if (progress.isActive || progress.status == BackupTaskStatus.paused) ...[
            _buildLiveProgressCard(context, ref, state, scheme),
            const SizedBox(height: AppSpacing.md),
          ],

          // 3. Failed Uploads Card with Retry (REQ-BAK-02)
          if (progress.failedItems > 0 && !progress.isActive) ...[
            _buildFailedItemsCard(context, ref, state, scheme),
            const SizedBox(height: AppSpacing.md),
          ],

          // 4. Completed Success Card (REQ-BAK-03)
          if (progress.status == BackupTaskStatus.completed &&
              progress.failedItems == 0) ...[
            _buildSuccessCard(context, ref, state, scheme),
            const SizedBox(height: AppSpacing.md),
          ],

          // 5. Category Selection & Preparation (when idle or ready)
          if (!progress.isActive &&
              progress.status != BackupTaskStatus.completed) ...[
            _buildCandidateSelectionCard(context, ref, state, scheme),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Account & Scope Card (REQ-BAK-01)
  // ---------------------------------------------------------------------------
  Widget _buildAccountCard(
    BuildContext context,
    WidgetRef ref,
    BackupState state,
    ColorScheme scheme,
  ) {
    final auth = state.authStatus;
    final isConnected = auth.isConnected;
    final email = auth.account?.email;
    final controller = ref.read(backupControllerProvider.notifier);

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerLow,
                    borderRadius: AppRadius.chipRadius,
                  ),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    color: isConnected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? 'Google Drive Connected' : 'Google Drive Disconnected',
                        style: AppTextStyles.titleSmall,
                      ),
                      if (email != null)
                        Text(
                          email,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isConnected)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                    onPressed: state.progress.isActive ? null : () => controller.signOut(),
                    child: const Text('Disconnect'),
                  )
                else
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                    onPressed: auth.isAuthenticating ? null : () => controller.signIn(),
                    child: auth.isAuthenticating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            // Privacy notice tag (REQ-BAK-01)
            Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Privacy-first: Uses drive.file scope only. WappTidy can only access files it creates, never your existing personal Drive files.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Candidate Selection Card
  // ---------------------------------------------------------------------------
  Widget _buildCandidateSelectionCard(
    BuildContext context,
    WidgetRef ref,
    BackupState state,
    ColorScheme scheme,
  ) {
    final controller = ref.read(backupControllerProvider.notifier);
    final canStart = state.authStatus.isConnected &&
        state.candidateItems.isNotEmpty &&
        !state.isLoadingCandidates;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Media to Back Up',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choose which categories to copy to your Google Drive.',
              style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Category filter chips
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: BackupCategoryFilter.values.map((filter) {
                final isSelected =
                    !state.isCustomSelection && state.selectedFilter == filter;
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) controller.loadCandidates(filter);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),

            // Candidate Summary (REQ-BAK-02, P-03)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready for backup',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (state.isLoadingCandidates)
                      const Text('Calculating...')
                    else
                      Text(
                        '${state.totalCandidateCount} items • ${formatBytes(state.totalCandidateBytes)}',
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: canStart ? () => controller.startBackup() : null,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Start Backup'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Live Progress Card (REQ-BAK-02)
  // ---------------------------------------------------------------------------
  Widget _buildLiveProgressCard(
    BuildContext context,
    WidgetRef ref,
    BackupState state,
    ColorScheme scheme,
  ) {
    final progress = state.progress;
    final controller = ref.read(backupControllerProvider.notifier);
    final isPaused = progress.status == BackupTaskStatus.paused;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPaused ? Icons.pause_circle_outline : Icons.sync,
                  color: isPaused ? scheme.error : scheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    isPaused ? 'Backup Paused' : 'Uploading to Google Drive...',
                    style: AppTextStyles.titleSmall,
                  ),
                ),
                Text(
                  '${progress.progressPercent}%',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppRadius.chipRadius,
              child: LinearProgressIndicator(
                value: progress.progressRatio,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.uploadedItems} of ${progress.totalItems} files',
                  style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  '${formatBytes(progress.uploadedBytes)} / ${formatBytes(progress.totalBytes)}',
                  style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            if (progress.currentItemName != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Uploading: ${progress.currentItemName}',
                style: AppTextStyles.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isPaused)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                    onPressed: () => controller.resumeBackup(),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Resume'),
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                    onPressed: () => controller.pauseBackup(),
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('Pause'),
                  ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () => controller.cancelBackup(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    foregroundColor: scheme.error,
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Failed Items Card & Retry (REQ-BAK-02)
  // ---------------------------------------------------------------------------
  Widget _buildFailedItemsCard(
    BuildContext context,
    WidgetRef ref,
    BackupState state,
    ColorScheme scheme,
  ) {
    final progress = state.progress;
    final controller = ref.read(backupControllerProvider.notifier);
    final failedList = progress.failedResults;

    return Card(
      elevation: 0,
      color: scheme.errorContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: scheme.error),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${progress.failedItems} items failed to upload',
                    style: AppTextStyles.titleSmall.copyWith(color: scheme.error),
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                  onPressed: () => controller.retryFailed(),
                  child: const Text('Retry Failed'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            ...failedList.take(5).map((f) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        f.item.displayName,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatBytes(f.item.sizeBytes),
                      style: AppTextStyles.bodySmall.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              );
            }),
            if (failedList.length > 5)
              Text(
                'and ${failedList.length - 5} more...',
                style: AppTextStyles.bodySmall.copyWith(color: scheme.outline),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Completion Card (REQ-BAK-03)
  // ---------------------------------------------------------------------------
  Widget _buildSuccessCard(
    BuildContext context,
    WidgetRef ref,
    BackupState state,
    ColorScheme scheme,
  ) {
    final progress = state.progress;
    final controller = ref.read(backupControllerProvider.notifier);

    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: scheme.primary,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Backup Complete!',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${progress.uploadedItems} files safely uploaded (${formatBytes(progress.uploadedBytes)})',
              style: AppTextStyles.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: AppRadius.chipRadius,
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.outline),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Your local files were preserved. WappTidy never auto-deletes media after backup.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // REQ-BAK-03: Never delete local originals after upload.
            // Post-backup CTA reads "Review originals", not "Delete originals".
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('review_originals_button'),
                onPressed: () => controller.reviewOriginals(context),
                child: const Text('Review originals'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
