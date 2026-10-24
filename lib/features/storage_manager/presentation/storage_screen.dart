// lib/features/storage_manager/presentation/storage_screen.dart
//
// Storage Manager: what WazApp stores (measured from disk), the biggest files,
// probable duplicates (explained, never auto-deleted) and safe clean-ups.
// Every deletion states how many files and how many bytes and needs a tap on "Delete".

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/app_error.dart';
import '../../../core/format.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../library/domain/library_models.dart';
import '../../private_folder/presentation/private_providers.dart';
import '../data/storage_service.dart';
import '../domain/storage_models.dart';

/// Recomputed whenever the library changes (items added, moved, deleted).
final storageReportProvider = FutureProvider.autoDispose<StorageReport>((
  ref,
) async {
  ref.watch(allMediaProvider);
  return ref.watch(storageServiceProvider).report();
});

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  final Set<String> _largeSelected = {};
  final Set<String> _dupSelected = {};
  List<DuplicateGroup>? _groups;
  bool _scanning = false;
  String _scanStage = '';
  bool _cancelScan = false;

  StorageService get _service => ref.read(storageServiceProvider);

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool destructive = true,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  int _bytesOf(Iterable<SavedMedia> items, Set<String> ids) =>
      items.where((m) => ids.contains(m.id)).fold(0, (a, m) => a + m.sizeBytes);

  Future<void> _deleteSelected(
    Set<String> selected,
    List<SavedMedia> pool,
  ) async {
    final chosen = pool.where((m) => selected.contains(m.id)).toList();
    if (chosen.isEmpty) return;
    final bytes = chosen.fold(0, (a, m) => a + m.sizeBytes);
    final ok = await _confirm(
      title: chosen.length == 1
          ? 'Delete 1 file?'
          : 'Delete ${chosen.length} files?',
      body:
          'This frees ${formatBytes(bytes)}. The files are removed from WazApp and cannot be recovered. '
          'Originals outside WazApp (WhatsApp, your gallery) are not affected.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    final r = await _service.deleteItems(chosen.map((m) => m.id));
    if (!mounted) return;
    final gone = chosen.map((m) => m.id).toSet()..removeAll(r.failedIds);
    setState(() {
      _largeSelected.removeAll(gone);
      _dupSelected.removeAll(gone);
      _groups = _groups
          ?.map(
            (g) => DuplicateGroup(
              reason: g.reason,
              items: g.items.where((m) => !gone.contains(m.id)).toList(),
            ),
          )
          .where((g) => g.items.length > 1)
          .toList();
    });
    ref.invalidate(storageReportProvider);
    _snack(
      r.failedIds.isEmpty
          ? 'Deleted ${r.deleted} file${r.deleted == 1 ? '' : 's'}, freed ${formatBytes(bytes)}'
          : 'Deleted ${r.deleted}; ${r.failedIds.length} could not be deleted',
    );
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _cancelScan = false;
      _scanStage = 'Starting…';
      _dupSelected.clear();
    });
    try {
      final scan = await _service.findDuplicates(
        onProgress: (stage, done, total) {
          if (mounted) setState(() => _scanStage = '$stage ($done of $total)');
        },
        isCancelled: () => _cancelScan,
      );
      if (!mounted) return;
      setState(() => _groups = scan.groups);
      if (_cancelScan) _snack('Scan stopped. Showing what was found so far.');
    } on AppError catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('The scan could not finish. Please try again.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(storageReportProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Manager'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(storageReportProvider),
          ),
        ],
      ),
      body: report.when(
        loading: () => const SkeletonListLoader(),
        error: (e, _) => ErrorState(
          message: 'Could not measure storage.',
          onRetry: () => ref.invalidate(storageReportProvider),
        ),
        data: (r) => ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            _Summary(report: r),
            _largeFiles(r),
            _duplicates(),
            _cleanup(r),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _largeFiles(StorageReport r) {
    return _Section(
      title: 'Largest files',
      subtitle: r.largeFiles.isEmpty
          ? 'No file in your library is larger than 1 MB.'
          : 'The biggest items in Saved (the Private Folder is never listed).',
      child: Column(
        children: [
          for (final m in r.largeFiles)
            CheckboxListTile(
              dense: true,
              value: _largeSelected.contains(m.id),
              onChanged: (v) => setState(
                () => v == true
                    ? _largeSelected.add(m.id)
                    : _largeSelected.remove(m.id),
              ),
              secondary: _Thumb(media: m),
              title: Text(
                m.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${formatBytes(m.sizeBytes)} · ${m.isVideo ? 'video' : 'photo'} · ${formatRelativeDate(m.savedAt)}',
              ),
            ),
          if (_largeSelected.isNotEmpty)
            _DeleteBar(
              label:
                  'Delete ${_largeSelected.length} selected (${formatBytes(_bytesOf(r.largeFiles, _largeSelected))})…',
              onPressed: () => _deleteSelected(_largeSelected, r.largeFiles),
            ),
        ],
      ),
    );
  }

  Widget _duplicates() {
    final groups = _groups;
    final all = [
      for (final g in groups ?? const <DuplicateGroup>[]) ...g.items,
    ];
    final allExtras = [
      for (final g in groups ?? const <DuplicateGroup>[]) ...g.suggestedExtras,
    ];
    return _Section(
      title: 'Probable duplicates',
      subtitle: 'WazApp only compares items in Saved. It never deletes anything by itself; you choose what to remove.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  icon: _scanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.content_copy),
                  label: Text(
                    groups == null ? 'Find duplicates' : 'Scan again',
                  ),
                  onPressed: _scanning ? null : _scan,
                ),
                if (_scanning) ...[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: () => setState(() => _cancelScan = true),
                    child: const Text('Stop'),
                  ),
                ],
              ],
            ),
          ),
          if (_scanning)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(_scanStage, style: AppTextStyles.bodySmall),
            ),
          if (groups != null && groups.isEmpty && !_scanning)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('No duplicates found.'),
            ),
          if (groups != null && groups.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(
                      () => _dupSelected
                        ..clear()
                        ..addAll(allExtras.map((m) => m.id)),
                    ),
                    child: Text(
                      'Select extras (${allExtras.length}) · keep the oldest of each',
                    ),
                  ),
                  if (_dupSelected.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(_dupSelected.clear),
                      child: const Text('Clear selection'),
                    ),
                ],
              ),
            ),
            for (final g in groups)
              _GroupCard(
                group: g,
                selected: _dupSelected,
                onToggle: (id, on) => setState(
                  () => on ? _dupSelected.add(id) : _dupSelected.remove(id),
                ),
              ),
            if (_dupSelected.isNotEmpty)
              _DeleteBar(
                label:
                    'Delete ${_dupSelected.length} selected (${formatBytes(_bytesOf(all, _dupSelected))})…',
                onPressed: () => _deleteSelected(_dupSelected, all),
              ),
          ],
        ],
      ),
    );
  }

  Widget _cleanup(StorageReport r) {
    final tiles = <Widget>[];
    if (r.unreferenced.isNotEmpty) {
      tiles.add(
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(
            '${r.unreferenced.length} unreferenced file${r.unreferenced.length == 1 ? '' : 's'} (${formatBytes(r.unreferencedBytes)})',
          ),
          subtitle: const Text(
            'Files inside WazApp that no library entry uses, for example left over from an interrupted save.',
          ),
          trailing: TextButton(
            child: const Text('Remove…'),
            onPressed: () async {
              final ok = await _confirm(
                title:
                    'Remove ${r.unreferenced.length} unreferenced file${r.unreferenced.length == 1 ? '' : 's'}?',
                body:
                    'This frees ${formatBytes(r.unreferencedBytes)}. None of them appear in Saved or the Private Folder.',
                action: 'Remove',
              );
              if (!ok) return;
              final res = await _service.deleteUnreferenced(r.unreferenced);
              ref.invalidate(storageReportProvider);
              _snack(
                'Removed ${res.deleted} file${res.deleted == 1 ? '' : 's'}, freed ${formatBytes(res.bytes)}'
                '${res.failed > 0 ? '; ${res.failed} skipped' : ''}',
              );
            },
          ),
        ),
      );
    }
    if (r.tempBytes > 0) {
      tiles.add(
        ListTile(
          leading: const Icon(Icons.hourglass_empty),
          title: Text('Temporary export files (${formatBytes(r.tempBytes)})'),
          subtitle: const Text(
            'Scratch space for photo and video exports. Never part of your library.',
          ),
          trailing: TextButton(
            child: const Text('Clear…'),
            onPressed: () async {
              final ok = await _confirm(
                title: 'Clear temporary files?',
                body:
                    'This frees ${formatBytes(r.tempBytes)}. Only scratch files from exports are removed.',
                action: 'Clear',
                destructive: false,
              );
              if (!ok) return;
              final freed = await _service.clearTemp();
              ref.invalidate(storageReportProvider);
              _snack('Freed ${formatBytes(freed)}');
            },
          ),
        ),
      );
    }
    if (r.missingIds.isNotEmpty) {
      tiles.add(
        ListTile(
          leading: const Icon(Icons.broken_image_outlined),
          title: Text(
            '${r.missingIds.length} broken entr${r.missingIds.length == 1 ? 'y' : 'ies'}',
          ),
          subtitle: const Text(
            'Library entries whose file no longer exists (for example after clearing app data).',
          ),
          trailing: TextButton(
            child: const Text('Remove…'),
            onPressed: () async {
              final ok = await _confirm(
                title:
                    'Remove ${r.missingIds.length} broken entr${r.missingIds.length == 1 ? 'y' : 'ies'}?',
                body: 'Only the empty entries are removed; there is no file left to delete.',
                action: 'Remove',
                destructive: false,
              );
              if (!ok) return;
              final n = await _service.removeBrokenEntries(r.missingIds);
              ref.invalidate(storageReportProvider);
              _snack('Removed $n entr${n == 1 ? 'y' : 'ies'}');
            },
          ),
        ),
      );
    }
    return _Section(
      title: 'Clean up',
      subtitle: tiles.isEmpty ? 'Nothing to clean up. WazApp is tidy.' : null,
      child: Column(children: tiles),
    );
  }
}

// -----------------------------------------------------------------------------

class _Summary extends StatelessWidget {
  const _Summary({required this.report});
  final StorageReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final segments = <(String, int, Color)>[
      ('Photos', report.photos.bytes, scheme.primary),
      ('Videos', report.videos.bytes, scheme.tertiary),
      ('Private', report.privateItems.bytes, scheme.secondary),
      (
        'Thumbnails & other',
        report.thumbnailBytes + report.tempBytes + report.unreferencedBytes,
        scheme.outline,
      ),
    ];
    final total = report.totalBytes;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatBytes(total), style: AppTextStyles.headlineMedium),
          Text(
            'used by WazApp on this device',
            style: AppTextStyles.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: SizedBox(
              height: 12,
              child: total == 0
                  ? ColoredBox(color: scheme.surfaceContainerHighest)
                  : Row(
                      children: [
                        for (final s in segments)
                          if (s.$2 > 0)
                            Expanded(
                              flex: (s.$2 * 1000 ~/ total).clamp(1, 1000),
                              child: ColoredBox(color: s.$3),
                            ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final s in segments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 10, color: s.$3),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.$1)),
                  Text(formatBytes(s.$2), style: AppTextStyles.labelLarge),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Saved: ${report.photos.count} photos · ${report.videos.count} videos. '
            'Private Folder: ${report.privateItems.count} item${report.privateItems.count == 1 ? '' : 's'} (details stay hidden here).',
            style: AppTextStyles.bodySmall,
          ),
          if (report.bySource.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  for (final e in report.bySource.entries)
                    '${_sourceLabel(e.key)}: ${e.value.count} (${formatBytes(e.value.bytes)})',
                ].join(' · '),
                style: AppTextStyles.bodySmall,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Only files WazApp keeps itself are counted. Your gallery, WhatsApp and other apps are not scanned.',
            style: AppTextStyles.bodySmall.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _sourceLabel(String key) => switch (key) {
    'status' => 'Statuses',
    'imported' => 'Imported',
    'created' => 'Created',
    'edited' => 'Edited',
    _ => key,
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(color: scheme.primary),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(subtitle!, style: AppTextStyles.bodySmall),
          ),
        child,
      ],
    );
  }
}

class _DeleteBar extends StatelessWidget {
  const _DeleteBar({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
      icon: const Icon(Icons.delete_outline),
      label: Text(label),
      onPressed: onPressed,
    ),
  );
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.selected,
    required this.onToggle,
  });
  final DuplicateGroup group;
  final Set<String> selected;
  final void Function(String id, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.reason.title, style: AppTextStyles.titleSmall),
              Text(
                group.reason.explanation,
                style: AppTextStyles.bodySmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Could free ${formatBytes(group.reclaimableBytes)}',
                style: AppTextStyles.labelMedium,
              ),
              for (var i = 0; i < group.items.length; i++)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: selected.contains(group.items[i].id),
                  onChanged: (v) => onToggle(group.items[i].id, v == true),
                  secondary: _Thumb(media: group.items[i]),
                  title: Text(
                    group.items[i].fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${formatBytes(group.items[i].sizeBytes)}'
                    '${group.items[i].width > 0 ? ' · ${group.items[i].width}×${group.items[i].height}' : ''}'
                    ' · ${formatRelativeDate(group.items[i].savedAt)}'
                    '${i == 0 ? ' · oldest (suggested to keep)' : ''}',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.media});
  final SavedMedia media;

  @override
  Widget build(BuildContext context) {
    final path = media.isVideo ? media.thumbnailPath : media.path;
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: path == null
            ? const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.videocam_outlined),
              )
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: 96,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
      ),
    );
  }
}
