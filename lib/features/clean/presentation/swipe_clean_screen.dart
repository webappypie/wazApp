// lib/features/clean/presentation/swipe_clean_screen.dart
//
// Full Swipe Clean screen with gesture deck, tutorial, and batch review (REQ-ACT-08, REQ-SWP-01..05).
//
// RULES:
//   - REQ-ACT-08: Left delete, right keep, up archive, tap preview.
//   - REQ-SWP-02: Undo always available.
//   - REQ-SWP-04: Batch review confirmation via ConfirmationSheet before trashing.
//   - REQ-ADS-05: Zero ads inside swipe sequence.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/action_widgets.dart';
import '../domain/category_models.dart';
import '../domain/swipe_clean_models.dart';
import 'media_preview_sheet.dart';
import 'swipe_clean_controller.dart';
import 'widgets/swipe_card.dart';

final swipeCleanItemsProvider = FutureProvider.autoDispose<List<CategoryItem>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final items = await (db.select(db.mediaItems)
        ..where((t) => t.isProtected.equals(false))
        ..limit(100))
      .get();

  return items.map((row) {
    return CategoryItem(
      id: row.id.toString(),
      contentUri: row.contentUri,
      displayName: row.displayName,
      mimeType: row.mimeType,
      sizeBytes: row.sizeBytes,
      dateAddedSec: row.dateAddedSec,
      dateModifiedSec: row.dateModifiedSec,
      bucketName: row.bucketName,
      sourceApp: row.sourceApp,
      width: row.width,
      height: row.height,
      durationMs: row.durationMs,
      isProtected: row.isProtected,
    );
  }).toList();
});

class SwipeCleanScreen extends ConsumerStatefulWidget {
  const SwipeCleanScreen({
    super.key,
    this.customCandidates,
    this.startWithTutorial = false,
  });

  final List<CategoryItem>? customCandidates;
  final bool startWithTutorial;

  @override
  ConsumerState<SwipeCleanScreen> createState() => _SwipeCleanScreenState();
}

class _SwipeCleanScreenState extends ConsumerState<SwipeCleanScreen> {
  SwipeCleanController? _controller;

  void _initController(List<CategoryItem> items) {
    _controller ??= SwipeCleanController(
      initialCandidates: items,
      isTutorialDismissed: !widget.startWithTutorial,
    );
  }

  Future<void> _handleCommit(SwipeSessionState state) async {
    final coordinator = ref.read(mediaActionCoordinatorProvider);
    final deleteCount = state.itemsToDelete.length;
    final deleteBytes = state.totalDeleteBytes;

    if (deleteCount == 0) {
      if (mounted) context.pop();
      return;
    }

    final confirmed = await ConfirmationSheet.show(
      context,
      title: 'Delete $deleteCount items?',
      body: 'This will move $deleteCount files (${formatBytes(deleteBytes)}) to Trash.',
      confirmLabel: 'Move to Trash',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      await _controller?.commitBatch(coordinator);
      if (mounted) {
        context.pop();
      }
    }
  }

  void _openPreview(CategoryItem item) {
    MediaPreviewSheet.show(
      context,
      item: item,
      isSelected: false,
      onToggleSelection: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.customCandidates != null) {
      _initController(widget.customCandidates!);
      return _buildDeckScaffold(scheme, _controller!);
    }

    final asyncCandidates = ref.watch(swipeCleanItemsProvider);

    return asyncCandidates.when(
      data: (items) {
        _initController(items);
        return _buildDeckScaffold(scheme, _controller!);
      },
      loading: () => Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(title: const Text('Swipe Clean')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(title: const Text('Swipe Clean')),
        body: Center(child: Text('Failed to load items: $e')),
      ),
    );
  }

  Widget _buildDeckScaffold(
    ColorScheme scheme,
    SwipeCleanController controller,
  ) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;

        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
            title: Text(
              state.isCompleted
                  ? 'Review Complete'
                  : '${state.remainingItems.length} items left',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.undo_rounded),
                tooltip: 'Undo last swipe',
                onPressed: state.canUndo ? controller.undo : null,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: state.progressFraction,
                minHeight: 4,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (state.isCompleted)
                _buildCompletedSummary(scheme, state)
              else if (state.candidates.isEmpty)
                _buildEmptyState(scheme)
              else
                _buildCardStack(scheme, controller, state),

              // REQ-SWP-05: First-use tutorial overlay
              if (!state.isTutorialDismissed)
                _buildTutorialOverlay(scheme, controller),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardStack(
    ColorScheme scheme,
    SwipeCleanController controller,
    SwipeSessionState state,
  ) {
    final current = state.currentCard;
    final next = state.nextCard;
    final third = state.thirdCard;

    return Column(
      children: [
        // Deck card container
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.md,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 3rd card lookahead
                if (third != null)
                  Transform.translate(
                    offset: const Offset(0, 24),
                    child: Transform.scale(
                      scale: 0.90,
                      child: SwipeCard(
                        key: ValueKey(third.id),
                        item: third,
                        isTop: false,
                        onSwipe: (_) {},
                        onTap: () {},
                      ),
                    ),
                  ),

                // 2nd card lookahead
                if (next != null)
                  Transform.translate(
                    offset: const Offset(0, 12),
                    child: Transform.scale(
                      scale: 0.95,
                      child: SwipeCard(
                        key: ValueKey(next.id),
                        item: next,
                        isTop: false,
                        onSwipe: (_) {},
                        onTap: () {},
                      ),
                    ),
                  ),

                // Top active card
                if (current != null)
                  SwipeCard(
                    key: ValueKey(current.id),
                    item: current,
                    isTop: true,
                    onSwipe: controller.recordSwipe,
                    onTap: () => _openPreview(current),
                  ),
              ],
            ),
          ),
        ),

        // Bottom manual action bar
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.pagePadding,
            right: AppSpacing.pagePadding,
            bottom: AppSpacing.lg,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Delete (Left)
              _ActionButton(
                icon: Icons.close_rounded,
                color: kColorDestructive,
                tooltip: 'Delete (Swipe Left)',
                onPressed: () => controller.recordSwipe(SwipeAction.delete),
              ),

              // Archive (Up)
              _ActionButton(
                icon: Icons.archive_outlined,
                color: Colors.blueAccent,
                tooltip: 'Archive (Swipe Up)',
                onPressed: () => controller.recordSwipe(SwipeAction.archive),
              ),

              // Undo
              _ActionButton(
                icon: Icons.undo_rounded,
                color: Colors.amber.shade700,
                tooltip: 'Undo',
                size: 44,
                onPressed: state.canUndo ? controller.undo : null,
              ),

              // Keep (Right)
              _ActionButton(
                icon: Icons.favorite_rounded,
                color: kColorSuccess,
                tooltip: 'Keep (Swipe Right)',
                onPressed: () => controller.recordSwipe(SwipeAction.keep),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedSummary(
    ColorScheme scheme,
    SwipeSessionState state,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 64,
              color: scheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Deck Review Complete!',
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Here is the summary of your choices:',
              style: AppTextStyles.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Summary metrics card
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Marked for Deletion',
                    value: '${state.itemsToDelete.length} files (${state.formattedTotalDeleteBytes})',
                    color: kColorDestructive,
                  ),
                  const Divider(height: AppSpacing.lg),
                  _SummaryRow(
                    label: 'Kept in Library',
                    value: '${state.itemsToKeep.length} files',
                    color: kColorSuccess,
                  ),
                  const Divider(height: AppSpacing.lg),
                  _SummaryRow(
                    label: 'Archived',
                    value: '${state.itemsToArchive.length} files',
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Commit / delete action
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _handleCommit(state),
                icon: const Icon(Icons.delete_sweep_rounded),
                label: Text(
                  state.itemsToDelete.isNotEmpty
                      ? 'Commit & Delete (${state.formattedTotalDeleteBytes})'
                      : 'Finish Review',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.style_outlined,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Media to Review',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your WhatsApp library is clean or no media items were found.',
              style: AppTextStyles.bodySmall.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialOverlay(
    ColorScheme scheme,
    SwipeCleanController controller,
  ) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Swipe Clean Gestures',
              style: AppTextStyles.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _TutorialItem(
              icon: Icons.arrow_back_rounded,
              color: kColorDestructive,
              title: 'Swipe Left',
              description: 'Mark file for deletion',
            ),
            const SizedBox(height: AppSpacing.lg),
            _TutorialItem(
              icon: Icons.arrow_forward_rounded,
              color: kColorSuccess,
              title: 'Swipe Right',
              description: 'Keep file in your chats',
            ),
            const SizedBox(height: AppSpacing.lg),
            _TutorialItem(
              icon: Icons.arrow_upward_rounded,
              color: Colors.blueAccent,
              title: 'Swipe Up',
              description: 'Archive file out of chat view',
            ),
            const SizedBox(height: AppSpacing.lg),
            _TutorialItem(
              icon: Icons.touch_app_rounded,
              color: Colors.white70,
              title: 'Tap Card',
              description: 'Fullscreen media preview',
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: controller.dismissTutorial,
                child: const Text('Got it! Start Cleaning'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.size = 54,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: size * 0.5,
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        fixedSize: Size(size, size),
        shape: const CircleBorder(),
      ),
      icon: Icon(icon),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        Text(
          value,
          style: AppTextStyles.labelLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TutorialItem extends StatelessWidget {
  const _TutorialItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
