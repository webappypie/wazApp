// lib/features/clean/presentation/media_preview_sheet.dart
//
// Modal sheet for full media preview when tapping an unselected item (REQ-CLN-01, P-01).
// Provides specialized previews:
//   - Images & Videos: full visual preview with video play indicator
//   - Voice Notes & Audio: interactive playback controls (play/pause, scrub, speed 1x/1.5x/2x)
//   - Documents: file inspection and system viewer launch (ACTION_VIEW)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/services/audio/audio_playback_service.dart';
import '../domain/category_models.dart';

class MediaPreviewSheet extends StatelessWidget {
  const MediaPreviewSheet({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onToggleSelection,
  });

  final CategoryItem item;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  static Future<void> show(
    BuildContext context, {
    required CategoryItem item,
    required bool isSelected,
    required VoidCallback onToggleSelection,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MediaPreviewSheet(
        item: item,
        isSelected: isSelected,
        onToggleSelection: onToggleSelection,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Title row with filename
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.displayName,
                      style: AppTextStyles.titleMedium.copyWith(color: scheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close preview',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Preview container: Audio / Document / Visual
              if (item.isAudio)
                _AudioPreviewWidget(item: item)
              else if (item.isDocument)
                _DocumentPreviewWidget(item: item)
              else
                _VisualPreviewWidget(item: item),

              const SizedBox(height: AppSpacing.md),

              // Metadata card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
                ),
                child: Column(
                  children: [
                    _MetadataRow(label: 'Size', value: item.formattedSize),
                    if (item.width > 0 && item.height > 0)
                      _MetadataRow(label: 'Resolution', value: '${item.width} × ${item.height}'),
                    if (item.formattedDuration != null)
                      _MetadataRow(label: 'Duration', value: item.formattedDuration!),
                    _MetadataRow(
                      label: 'Type',
                      value: item.isDocument ? item.documentTypeLabel : item.mimeType,
                    ),
                    _MetadataRow(label: 'Folder', value: item.bucketName),
                    _MetadataRow(
                      label: 'Source',
                      value: item.sourceApp.contains('w4b') ? 'WhatsApp Business' : 'WhatsApp',
                    ),
                    if (item.isProtected)
                      _MetadataRow(label: 'Status', value: 'Protected (Keep Forever)'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Actions: Toggle selection & dismiss
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 20,
                      ),
                      label: Text(isSelected ? 'Deselect' : 'Select'),
                      onPressed: () {
                        onToggleSelection();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      child: const Text('Close'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Visual media preview (Images / Videos)
// ---------------------------------------------------------------------------

class _VisualPreviewWidget extends StatelessWidget {
  const _VisualPreviewWidget({required this.item});
  final CategoryItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: scheme.surfaceContainerHighest,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image(
                image: item.safeThumbnail,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    item.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (item.isVideo)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, size: 36, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Audio / Voice Note playback preview (P-01)
// ---------------------------------------------------------------------------

class _AudioPreviewWidget extends ConsumerStatefulWidget {
  const _AudioPreviewWidget({required this.item});
  final CategoryItem item;

  @override
  ConsumerState<_AudioPreviewWidget> createState() => _AudioPreviewWidgetState();
}

class _AudioPreviewWidgetState extends ConsumerState<_AudioPreviewWidget> {
  double _selectedSpeed = 1.0;
  AudioPlaybackService? _player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _player = ref.read(audioPlaybackServiceProvider);
  }

  @override
  void dispose() {
    _player?.stop();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final player = ref.watch(audioPlaybackServiceProvider);
    final isPtt = widget.item.isVoiceNote;

    return StreamBuilder<AudioPlaybackSnapshot>(
      stream: player.snapshotStream,
      initialData: player.currentSnapshot,
      builder: (context, snapshot) {
        final state = snapshot.data ?? player.currentSnapshot;
        final isCurrentItem = state.currentUri == widget.item.contentUri;
        final isPlaying = isCurrentItem && state.isPlaying;
        final duration = widget.item.durationMs > 0
            ? Duration(milliseconds: widget.item.durationMs)
            : (state.duration > Duration.zero ? state.duration : const Duration(seconds: 30));
        final position = isCurrentItem ? state.position : Duration.zero;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              // Audio Icon & Type Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isPtt
                          ? Colors.deepOrange.withValues(alpha: 0.15)
                          : Colors.deepPurple.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPtt ? Icons.mic_rounded : Icons.music_note_rounded,
                      color: isPtt ? Colors.deepOrange : Colors.deepPurple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPtt ? 'Voice Note Preview' : 'Audio Clip Preview',
                          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          isPtt ? 'Listen before deleting to avoid losing memories' : 'Playback audio clip',
                          style: AppTextStyles.labelSmall.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  // Playback speed toggle
                  MenuAnchor(
                    builder: (context, controller, child) => TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                      child: Text(
                        '${_selectedSpeed}x',
                        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
                      ),
                    ),
                    menuChildren: [1.0, 1.5, 2.0].map((speed) {
                      return MenuItemButton(
                        child: Text('${speed}x'),
                        onPressed: () {
                          setState(() => _selectedSpeed = speed);
                          player.setSpeed(speed);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Scrub Slider
              Slider(
                value: duration.inMilliseconds > 0
                    ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                    : 0.0,
                onChanged: (ratio) {
                  final targetMs = (ratio * duration.inMilliseconds).round();
                  player.seek(Duration(milliseconds: targetMs));
                },
              ),

              // Time labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position), style: AppTextStyles.labelSmall),
                    Text(_formatDuration(duration), style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Play / Pause main button
              FilledButton.icon(
                icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(isPlaying ? 'Pause Audio' : 'Play Audio'),
                onPressed: () {
                  if (isPlaying) {
                    player.pause();
                  } else if (isCurrentItem && state.isPaused) {
                    player.resume();
                  } else {
                    player.play(widget.item.contentUri, durationHint: duration);
                    player.setSpeed(_selectedSpeed);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Document preview card (P-01)
// ---------------------------------------------------------------------------

class _DocumentPreviewWidget extends ConsumerWidget {
  const _DocumentPreviewWidget({required this.item});
  final CategoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ext = item.fileExtension.toLowerCase();

    final IconData icon;
    final Color iconColor;
    final Color bgColor;

    if (ext == '.pdf' || item.mimeType == 'application/pdf') {
      icon = Icons.picture_as_pdf_rounded;
      iconColor = Colors.red;
      bgColor = Colors.red.withValues(alpha: 0.12);
    } else if (['.zip', '.rar', '.7z'].contains(ext)) {
      icon = Icons.folder_zip_rounded;
      iconColor = Colors.amber.shade900;
      bgColor = Colors.amber.withValues(alpha: 0.15);
    } else {
      icon = Icons.description_rounded;
      iconColor = Colors.blue;
      bgColor = Colors.blue.withValues(alpha: 0.12);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 36),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.documentTypeLabel,
            style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.displayName,
            style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open in System Viewer'),
            onPressed: () async {
              final coordinator = ref.read(mediaActionCoordinatorProvider);
              final opened = await coordinator.openMediaItem(
                contentUri: item.contentUri,
                mimeType: item.mimeType,
              );
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No suitable application found to open this document.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metadata row component
// ---------------------------------------------------------------------------

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: scheme.outline),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
