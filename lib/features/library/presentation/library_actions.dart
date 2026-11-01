// lib/features/library/presentation/library_actions.dart
//
// User-facing flows that combine pickers, progress UI and LibraryService calls.
// Every flow reports real results: success is only shown for items that were
// verified and persisted, and failures are listed instead of hidden.

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/app_error.dart';
import '../../../integrations/wapcentral/ads/full_screen_ads.dart';
import '../../../core/router/app_router.dart';
import '../../status/domain/status_models.dart';
import '../../status/presentation/status_providers.dart';
import '../data/library_service.dart';

const _filesExtensions = [
  'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif', //
  'mp4', 'm4v', 'mov', '3gp', 'mkv', 'webm',
];

/// Progress model shared by the progress dialog.
class BatchProgress extends ValueNotifier<(int done, int total)> {
  BatchProgress(int total) : super((0, total));
  bool cancelled = false;
}

Future<T> _withProgressDialog<T>(
  BuildContext context, {
  required String title,
  required BatchProgress progress,
  required Future<T> Function() work,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(title),
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (_, v, _) {
            final (done, total) = v;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: total == 0 ? null : done / total),
                const SizedBox(height: 12),
                Text('$done of $total'),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => progress.cancelled = true,
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
  try {
    return await work();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

void _snack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ));
}

Future<void> _showFailures(
  BuildContext context, {
  required String title,
  required List<String> messages,
  VoidCallback? onRetry,
}) {
  final unique = messages.toSet().toList();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final m in unique) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $m'))],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        if (onRetry != null)
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRetry();
            },
            child: const Text('Retry'),
          ),
      ],
    ),
  );
}

String _messageOf(AppError e) => e.message;

// -----------------------------------------------------------------------------
// Save statuses
// -----------------------------------------------------------------------------

Future<SaveBatchResult?> saveStatusesFlow(
  BuildContext context,
  WidgetRef ref,
  List<StatusItem> items, {
  VoidCallback? onViewSaved,
}) async {
  if (items.isEmpty) return null;
  // Re-check each source's real access first: it can be revoked while WazApp is in the background.
  final access = ref.read(statusAccessServiceProvider);
  for (final app in {for (final i in items) i.app}) {
    if (await access.folderState(app) == StatusFolderState.granted) continue;
    ref.invalidate(statusAccessProvider(app));
    ref.invalidate(statusListProvider(app));
    if (context.mounted) {
      _snack(
        context,
        'Access to ${app.label} statuses was lost. Choose its folder again in Settings.',
        actionLabel: 'Settings',
        onAction: () => GoRouter.of(context).go(AppRoutes.settings),
      );
    }
    return null;
  }
  if (!context.mounted) return null;
  final service = ref.read(libraryServiceProvider);
  final progress = BatchProgress(items.length);
  final result = await _withProgressDialog(
    context,
    title: items.length == 1 ? 'Saving…' : 'Saving ${items.length} items…',
    progress: progress,
    work: () => service.saveStatuses(
      items,
      onProgress: (d, t) => progress.value = (d, t),
      isCancelled: () => progress.cancelled,
    ),
  );
  if (!context.mounted) return result;

  final savedCount = result.saved.length;
  final parts = <String>[
    if (savedCount > 0) 'Saved $savedCount',
    if (result.alreadySaved.isNotEmpty) '${result.alreadySaved.length} already saved',
    if (result.failed.isNotEmpty) '${result.failed.length} failed',
    if (result.cancelled) 'cancelled',
  ];
  _snack(
    context,
    parts.isEmpty ? 'Nothing to save' : parts.join(' · '),
    actionLabel: savedCount > 0 && onViewSaved != null ? 'View' : null,
    onAction: onViewSaved,
  );
  if (result.failed.isNotEmpty) {
    await _showFailures(
      context,
      title: 'Some items could not be saved',
      messages: result.failed.map((f) => _messageOf(f.error)).toList(),
      onRetry: () => saveStatusesFlow(context, ref, result.failed.map((f) => f.item).toList(), onViewSaved: onViewSaved),
    );
  }
  // A natural break after a successful save (never on failure/cancel); the ad layer applies its own caps.
  if (savedCount > 0 && context.mounted) {
    unawaited(Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (context.mounted) ref.read(fullScreenAdsProvider).afterStatusSave(context, savedCount);
    }));
  }
  return result;
}

// -----------------------------------------------------------------------------
// Import
// -----------------------------------------------------------------------------

enum ImportSource { photos, files }

Future<ImportBatchResult?> importFlow(BuildContext context, WidgetRef ref, ImportSource source) async {
  List<ImportCandidate> picked;
  try {
    picked = switch (source) {
      ImportSource.photos => [
          for (final x in await ImagePicker().pickMultipleMedia())
            ImportCandidate(path: x.path, name: x.name, mimeType: x.mimeType),
        ],
      ImportSource.files => [
          for (final f in await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: _filesExtensions,
          ))
            if (f.path != null) ImportCandidate(path: f.path!, name: f.name),
        ],
    };
  } catch (e) {
    if (context.mounted) _snack(context, 'The picker could not be opened. Please try again.');
    return null;
  }
  if (picked.isEmpty || !context.mounted) return null;

  final service = ref.read(libraryServiceProvider);
  final progress = BatchProgress(picked.length);
  final result = await _withProgressDialog(
    context,
    title: 'Importing…',
    progress: progress,
    work: () => service.importFiles(
      picked,
      onProgress: (d, t) => progress.value = (d, t),
      isCancelled: () => progress.cancelled,
    ),
  );
  // Picker copies live in the app cache; remove them now that they are imported.
  for (final c in picked) {
    try {
      final f = File(c.path);
      if (f.path.contains('cache') && await f.exists()) await f.delete();
    } on FileSystemException {
      // Cache entries are cleaned by the OS eventually.
    }
  }
  if (!context.mounted) return result;
  _snack(
    context,
    [
      if (result.imported.isNotEmpty) 'Imported ${result.imported.length}',
      if (result.failed.isNotEmpty) '${result.failed.length} failed',
    ].join(' · '),
  );
  if (result.failed.isNotEmpty) {
    await _showFailures(
      context,
      title: 'Some items could not be imported',
      messages: result.failed.map((f) => _messageOf(f.error)).toList(),
    );
  }
  return result;
}

Future<void> showImportSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('From Photos'),
            subtitle: const Text('Pick photos and videos from your gallery'),
            onTap: () {
              Navigator.pop(ctx);
              importFlow(context, ref, ImportSource.photos);
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('From Files'),
            subtitle: const Text('Pick photo or video files from storage'),
            onTap: () {
              Navigator.pop(ctx);
              importFlow(context, ref, ImportSource.files);
            },
          ),
        ],
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Delete / share / export / favourite on saved items
// -----------------------------------------------------------------------------

Future<bool> confirmDelete(BuildContext context, int count) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(count == 1 ? 'Delete this item?' : 'Delete $count items?'),
      content: Text(
        count == 1
            ? 'It will be removed from WazApp and its file deleted from this device. This cannot be undone.'
            : 'These $count items will be removed from WazApp and their files deleted from this device. This cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Confirms, deletes, and reports the true outcome. Returns the result or null if declined.
Future<DeleteResult?> deleteFlow(BuildContext context, WidgetRef ref, List<String> ids) async {
  if (ids.isEmpty || !await confirmDelete(context, ids.length)) return null;
  final result = await ref.read(libraryServiceProvider).delete(ids);
  if (!context.mounted) return result;
  if (result.failedIds.isEmpty) {
    _snack(context, result.deleted == 1 ? 'Deleted' : 'Deleted ${result.deleted} items');
  } else {
    _snack(context, 'Deleted ${result.deleted}; ${result.failedIds.length} could not be deleted');
  }
  return result;
}

/// Moves items into the Private Folder (hidden from Saved) and reports the real outcome.
Future<PrivacyMoveResult?> moveToPrivateFlow(BuildContext context, WidgetRef ref, List<String> ids) async {
  if (ids.isEmpty) return null;
  final r = await ref.read(libraryServiceProvider).moveToPrivate(ids);
  if (!context.mounted) return r;
  if (r.failedIds.isEmpty) {
    _snack(context, r.moved == 1 ? 'Moved to your Private Folder' : 'Moved ${r.moved} items to your Private Folder');
  } else {
    _snack(context, 'Moved ${r.moved}; ${r.failedIds.length} could not be moved and were left where they are');
  }
  return r;
}

/// Returns items from the Private Folder to Saved.
Future<PrivacyMoveResult?> restoreFromPrivateFlow(BuildContext context, WidgetRef ref, List<String> ids) async {
  if (ids.isEmpty) return null;
  final r = await ref.read(libraryServiceProvider).restoreFromPrivate(ids);
  if (!context.mounted) return r;
  if (r.failedIds.isEmpty) {
    _snack(context, r.moved == 1 ? 'Moved back to Saved' : 'Moved ${r.moved} items back to Saved');
  } else {
    _snack(context, 'Moved ${r.moved}; ${r.failedIds.length} could not be moved');
  }
  return r;
}

Future<void> shareMedia(BuildContext context, List<SavedMedia> items) async {
  final existing = [for (final m in items) if (await File(m.path).exists()) m];
  if (!context.mounted) return;
  if (existing.isEmpty) {
    _snack(context, 'These files are no longer available.');
    return;
  }
  try {
    await SharePlus.instance.share(ShareParams(
      files: [for (final m in existing) XFile(m.path, mimeType: m.mimeType, name: m.fileName)],
    ));
  } catch (e) {
    if (context.mounted) _snack(context, 'Sharing is not available right now.');
  }
}

Future<void> exportFlow(BuildContext context, WidgetRef ref, List<SavedMedia> items) async {
  final service = ref.read(libraryServiceProvider);
  var ok = 0;
  final errors = <String>[];
  for (final m in items) {
    try {
      await service.exportToGallery(m);
      ok++;
    } on AppError catch (e) {
      errors.add(e.message);
    }
  }
  if (!context.mounted) return;
  if (errors.isEmpty) {
    _snack(context, ok == 1 ? 'Saved to your gallery (WazApp folder)' : 'Saved $ok items to your gallery');
  } else {
    _snack(context, ok == 0 ? errors.first : 'Saved $ok; ${errors.length} failed');
  }
}
