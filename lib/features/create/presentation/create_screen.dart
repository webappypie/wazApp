// lib/features/create/presentation/create_screen.dart
//
// Entry point for creating content. Only tools that really work are listed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/media_tile.dart';
import '../../library/domain/library_models.dart';
import '../../status_maker/domain/status_templates.dart';
import '../../library/presentation/library_actions.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/saved_screen.dart' show SavedThumb;

class CreateScreen extends ConsumerWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _ToolCard(
            icon: Icons.photo_filter_outlined,
            title: 'Edit a photo',
            body: 'Crop, rotate, adjust colours, apply filters, add text and stickers. '
                'Your original photo is never changed.',
            onTap: () => pickMediaToEdit(context, ref, MediaKind.image),
          ),
          if (ref.watch(videoEncoderProvider).isSupported) ...[
            const SizedBox(height: AppSpacing.md),
            _ToolCard(
              icon: Icons.movie_edit,
              title: 'Edit a video',
              body: 'Trim, mute, crop and add text or stickers. Saved as a new MP4; your original is never changed.',
              onTap: () => pickMediaToEdit(context, ref, MediaKind.video),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _ToolCard(
            icon: Icons.format_quote_rounded,
            title: 'Text status',
            body: 'Make a status image in English or हिन्दी from ${kStatusTemplates.length} designs.',
            onTap: () => context.push(AppRoutes.statusMaker),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.icon, required this.title, required this.body, required this.onTap});
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: title,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(icon, color: scheme.onPrimaryContainer, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.titleMedium),
                      const SizedBox(height: 4),
                      Text(body, style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets the user choose a photo or video from the library (or import one) and opens its editor.
Future<void> pickMediaToEdit(BuildContext context, WidgetRef ref, MediaKind kind) async {
  final id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _MediaPickerSheet(kind: kind),
  );
  if (id != null && context.mounted) {
    context.push(kind == MediaKind.video ? AppRoutes.videoEditor : AppRoutes.photoEditor, extra: id);
  }
}

class _MediaPickerSheet extends ConsumerWidget {
  const _MediaPickerSheet({required this.kind});
  final MediaKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider);
    final media = (items.value ?? const <SavedMedia>[]).where((m) => m.mediaKind == kind).toList();
    final noun = kind == MediaKind.video ? 'video' : 'photo';
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(child: Text('Choose a $noun', style: AppTextStyles.titleMedium)),
                  TextButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Import'),
                    onPressed: () => showImportSheet(context, ref),
                  ),
                ],
              ),
            ),
            Expanded(
              child: media.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text('No ${noun}s yet. Import one, or save a status first.', textAlign: TextAlign.center),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 110,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                      ),
                      itemCount: media.length,
                      itemBuilder: (context, i) {
                        final m = media[i];
                        return MediaTile(
                          semanticLabel: '$noun ${m.fileName}',
                          isVideo: m.isVideo,
                          duration: m.isVideo ? m.duration : null,
                          onTap: () => Navigator.pop(context, m.id),
                          child: SavedThumb(media: m),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
