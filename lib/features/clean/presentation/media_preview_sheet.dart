// lib/features/clean/presentation/media_preview_sheet.dart
//
// Modal sheet for full media preview when tapping an unselected item (REQ-CLN-01).

import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
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
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),

            // Top bar: title and close
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

            // Visual media preview container
            ClipRRect(
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
                            item.isVideo
                                ? Icons.videocam_outlined
                                : item.isAudio
                                    ? Icons.audiotrack_outlined
                                    : Icons.image_outlined,
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
            ),
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
                  _MetadataRow(label: 'Type', value: item.mimeType),
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
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
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

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
          ),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
