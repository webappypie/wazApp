// lib/features/create/presentation/create_screen.dart
//
// Entry point for creating content. Only tools that really work are listed.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/router/app_router.dart';
import '../../library/domain/library_models.dart';
import '../../status_maker/domain/status_templates.dart';
import '../../library/presentation/library_actions.dart';
import '../../library/presentation/library_providers.dart';

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
            onTap: () => pickPhotoToEdit(context, ref),
          ),
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

/// Lets the user choose a photo from the library (or import one) and opens the editor.
Future<void> pickPhotoToEdit(BuildContext context, WidgetRef ref) async {
  final id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _PhotoPickerSheet(),
  );
  if (id != null && context.mounted) context.push(AppRoutes.photoEditor, extra: id);
}

class _PhotoPickerSheet extends ConsumerWidget {
  const _PhotoPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider);
    final photos = (items.value ?? const <SavedMedia>[]).where((m) => m.mediaKind == MediaKind.image).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  const Expanded(child: Text('Choose a photo', style: AppTextStyles.titleMedium)),
                  TextButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Import'),
                    onPressed: () => showImportSheet(context, ref),
                  ),
                ],
              ),
            ),
            Expanded(
              child: photos.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'No photos yet. Import one, or save a status first.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 110,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (context, i) {
                        final m = photos[i];
                        return Semantics(
                          button: true,
                          label: 'Photo ${m.fileName}',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: () => Navigator.pop(context, m.id),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Image.file(
                                File(m.path),
                                fit: BoxFit.cover,
                                cacheWidth: 240,
                                excludeFromSemantics: true,
                                errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
                              ),
                            ),
                          ),
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
