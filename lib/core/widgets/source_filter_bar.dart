// lib/core/widgets/source_filter_bar.dart
//
// Reusable source filter bar for WhatsApp and WhatsApp Business.
// Options: [ All ] [ WhatsApp ] [ Business ]
//
// Automatically hides if only one source is installed and no media from the other
// source is present, keeping single-source users completely clutter-free.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../di/providers.dart';
import '../services/installed_apps/installed_apps_service.dart';

class SourceFilterBar extends ConsumerWidget {
  const SourceFilterBar({
    super.key,
    this.selectedFilter,
    this.onFilterChanged,
    this.forceVisible = false,
  });

  /// Override active filter. If null, reads from [activeSourceFilterProvider].
  final MediaSourceFilter? selectedFilter;

  /// Callback when a filter is tapped. If null, updates [activeSourceFilterProvider].
  final ValueChanged<MediaSourceFilter>? onFilterChanged;

  /// If true, always displays the filter even if only one app is detected.
  final bool forceVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installedAsync = ref.watch(installedSourcesProvider);
    final installed = installedAsync.value ?? InstalledSources.whatsAppOnly;

    // Do not show source filter if only one source exists unless forced (REQ-02, REQ-05).
    if (!forceVisible && !installed.hasBoth) {
      return const SizedBox.shrink();
    }

    final activeFilter = selectedFilter ?? ref.watch(activeSourceFilterProvider);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<MediaSourceFilter>(
          segments: const [
            ButtonSegment(
              value: MediaSourceFilter.all,
              label: Text('All'),
              icon: Icon(Icons.all_inclusive_rounded, size: 16),
            ),
            ButtonSegment(
              value: MediaSourceFilter.whatsApp,
              label: Text('WhatsApp'),
              icon: Icon(Icons.chat_bubble_outline_rounded, size: 16),
            ),
            ButtonSegment(
              value: MediaSourceFilter.whatsAppBusiness,
              label: Text('Business'),
              icon: Icon(Icons.business_center_outlined, size: 16),
            ),
          ],
          selected: {activeFilter ?? MediaSourceFilter.all},
          onSelectionChanged: (selected) {
            if (selected.isNotEmpty) {
              final newFilter = selected.first;
              if (onFilterChanged != null) {
                onFilterChanged!(newFilter);
              } else {
                ref.read(activeSourceFilterProvider.notifier).setFilter(newFilter);
              }
            }
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: WidgetStateProperty.all(
              AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
