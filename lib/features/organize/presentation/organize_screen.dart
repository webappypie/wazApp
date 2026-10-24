// lib/features/organize/presentation/organize_screen.dart
//
// Organize screen supporting cross-app media organization, collections, and file actions (REQ-12).
// Works seamlessly across WhatsApp and WhatsApp Business media.

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/action_widgets.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/media_tiles.dart';
import '../../../core/widgets/source_badge.dart';
import '../../../core/widgets/source_filter_bar.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../clean/data/media_action_coordinator.dart';
import '../../clean/domain/category_models.dart';

class CollectionDef {
  const CollectionDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

const _kDefaultCollections = [
  CollectionDef(
    id: 'receipts',
    title: 'Invoices & Receipts',
    description: 'Invoices, bills, orders & payment proofs',
    icon: Icons.receipt_long_rounded,
    color: Color(0xFF00897B),
  ),
  CollectionDef(
    id: 'business_docs',
    title: 'Business Documents',
    description: 'Contracts, spreadsheets & presentations',
    icon: Icons.business_center_rounded,
    color: Color(0xFF1E88E5),
  ),
  CollectionDef(
    id: 'protected',
    title: 'Protected Media',
    description: 'Files marked safe from cleanup',
    icon: Icons.shield_rounded,
    color: Color(0xFF43A047),
  ),
  CollectionDef(
    id: 'archives',
    title: 'Zip & Archive Files',
    description: 'Compressed bundles and zip archives',
    icon: Icons.folder_zip_rounded,
    color: Color(0xFF8E24AA),
  ),
  CollectionDef(
    id: 'photos_videos',
    title: 'All Visual Media',
    description: 'Combined images and videos from all chats',
    icon: Icons.photo_library_rounded,
    color: Color(0xFFFB8C00),
  ),
];

class OrganizeScreen extends ConsumerStatefulWidget {
  const OrganizeScreen({super.key});

  @override
  ConsumerState<OrganizeScreen> createState() => _OrganizeScreenState();
}

class _OrganizeScreenState extends ConsumerState<OrganizeScreen> {
  CollectionDef? _activeCollection;

  @override
  Widget build(BuildContext context) {
    if (_activeCollection != null) {
      return _CollectionDetailView(
        collection: _activeCollection!,
        onBack: () => setState(() => _activeCollection = null),
      );
    }

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Organize'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          Text(
            'Smart Collections',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Organize and manage media across WhatsApp and WhatsApp Business without modifying your original chat messages.',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          ..._kDefaultCollections.map((col) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CollectionCard(
                  collection: col,
                  onTap: () => setState(() => _activeCollection = col),
                ),
              )),
        ],
      ),
    );
  }
}

class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({
    required this.collection,
    required this.onTap,
  });

  final CollectionDef collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: collection.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(collection.icon, color: collection.color, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.title,
                      style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      collection.description,
                      style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionDetailView extends ConsumerStatefulWidget {
  const _CollectionDetailView({
    required this.collection,
    required this.onBack,
  });

  final CollectionDef collection;
  final VoidCallback onBack;

  @override
  ConsumerState<_CollectionDetailView> createState() => _CollectionDetailViewState();
}

class _CollectionDetailViewState extends ConsumerState<_CollectionDetailView> {
  final Set<String> _selectedIds = {};

  Future<List<CategoryItem>> _loadItems() async {
    final db = ref.read(appDatabaseProvider);
    final sourceFilter = ref.watch(activeSourceFilterProvider);

    var expr = switch (widget.collection.id) {
      'receipts' => db.mediaItems.displayName.like('%invoice%') |
          db.mediaItems.displayName.like('%receipt%') |
          db.mediaItems.displayName.like('%bill%') |
          db.mediaItems.displayName.like('%order%') |
          db.mediaItems.displayName.like('%slip%') |
          db.mediaItems.displayName.like('%statement%'),
      'business_docs' => db.mediaItems.sourceApp.equals('com.whatsapp.w4b') &
          (db.mediaItems.mimeType.like('application/%') | db.mediaItems.mimeType.like('text/%')),
      'protected' => db.mediaItems.isProtected.equals(true),
      'archives' => db.mediaItems.displayName.like('%.zip') |
          db.mediaItems.displayName.like('%.rar') |
          db.mediaItems.displayName.like('%.7z') |
          db.mediaItems.mimeType.like('%zip%'),
      'photos_videos' =>
        db.mediaItems.mimeType.like('image/%') | db.mediaItems.mimeType.like('video/%'),
      _ => const CustomExpression<bool>('1 = 1'),
    };

    if (sourceFilter == MediaSourceFilter.whatsApp) {
      expr = expr & db.mediaItems.sourceApp.equals('com.whatsapp');
    } else if (sourceFilter == MediaSourceFilter.whatsAppBusiness) {
      expr = expr & db.mediaItems.sourceApp.equals('com.whatsapp.w4b');
    }

    final rows = await (db.select(db.mediaItems)
          ..where((t) => expr)
          ..orderBy([(t) => OrderingTerm.desc(t.dateModifiedSec)]))
        .get();

    return rows
        .map((r) => CategoryItem(
              id: r.id.toString(),
              contentUri: r.contentUri,
              displayName: r.displayName,
              mimeType: r.mimeType,
              sizeBytes: r.sizeBytes,
              dateAddedSec: r.dateAddedSec,
              dateModifiedSec: r.dateModifiedSec,
              bucketName: r.bucketName,
              sourceApp: r.sourceApp,
              width: r.width,
              height: r.height,
              durationMs: r.durationMs,
              isProtected: r.isProtected,
            ))
        .toList();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoryItem>>(
      future: _loadItems(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final selectedItems =
            items.where((it) => _selectedIds.contains(it.id)).toList();
        final selectedBytes =
            selectedItems.fold<int>(0, (sum, it) => sum + it.sizeBytes);

        return AppScaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onBack,
            ),
            title: Text(widget.collection.title),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedIds.length == items.length) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.addAll(items.map((e) => e.id));
                      }
                    });
                  },
                  child: Text(_selectedIds.length == items.length
                      ? 'Deselect All'
                      : 'Select All'),
                ),
            ],
          ),
          bottomNavigationBar: _selectedIds.isNotEmpty
              ? BottomActionBar(
                  selectionCount: _selectedIds.length,
                  selectionSizeLabel:
                      '${_selectedIds.length} items • ${formatBytes(selectedBytes)}',
                  onDelete: () => _handleDelete(selectedItems),
                  onMove: () => _handleMove(selectedItems),
                  onProtect: () => _handleProtect(selectedItems),
                )
              : null,
          body: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  AppSpacing.xs,
                  AppSpacing.pagePadding,
                  AppSpacing.xs,
                ),
                child: SourceFilterBar(),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? const EmptyState(
                            title: 'No files in this collection',
                            body: 'Files matching this collection will appear here.',
                            icon: Icons.folder_open_outlined,
                          )
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isSelected = _selectedIds.contains(item.id);

                              return MediaListRow(
                                thumbnailProvider: item.safeThumbnail,
                                title: item.displayName,
                                subtitle:
                                    '${item.bucketName.isNotEmpty ? "${item.bucketName} • " : ""}${formatBytes(item.sizeBytes)}',
                                sourceApp: item.sourceApp,
                                isSelected: isSelected,
                                isProtected: item.isProtected,
                                onTap: () => _toggleSelection(item.id),
                                onLongPress: () => _toggleSelection(item.id),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleDelete(List<CategoryItem> items) async {
    final confirmed = await ConfirmationSheet.show(
      context,
      title: 'Move to Recycle Bin?',
      body: 'Items can be safely restored to their respective apps within 30 days.',
      confirmLabel: 'Move to Bin',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      final coordinator = ref.read(mediaActionCoordinatorProvider);
      await coordinator.trashSelected(items);
      setState(() => _selectedIds.clear());
    }
  }

  Future<void> _handleMove(List<CategoryItem> items) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Media relocation ready. Select target destination.')),
    );
  }

  Future<void> _handleProtect(List<CategoryItem> items) async {
    final coordinator = ref.read(mediaActionCoordinatorProvider);
    await coordinator.setProtection(items, true);
    setState(() => _selectedIds.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length} items protected from cleanup.')),
      );
    }
  }
}
