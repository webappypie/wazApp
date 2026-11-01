// lib/features/status/presentation/status_providers.dart

import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../library/domain/library_models.dart';
import '../domain/status_models.dart';

/// Which WhatsApp variants are installed (drives the source switcher).
final installedAppsProvider = FutureProvider<Map<StatusApp, bool>>(
  (ref) => ref.watch(statusAccessServiceProvider).installedApps(),
);

/// Whether the user's folder grant for [app] is still valid.
final statusAccessProvider = FutureProvider.family<bool, StatusApp>(
  (ref, app) => ref.watch(statusAccessServiceProvider).hasAccess(app),
);

/// The real folder state for [app] (not configured / granted / access lost / folder missing).
final statusFolderStateProvider = FutureProvider.family<StatusFolderState, StatusApp>(
  (ref, app) => ref.watch(statusAccessServiceProvider).folderState(app),
);

/// Installed WhatsApp variants only, in display order. Empty when neither is installed.
final availableSourcesProvider = FutureProvider<List<StatusApp>>((ref) async {
  final apps = await ref.watch(installedAppsProvider.future);
  return [for (final a in StatusApp.values) if (apps[a] == true) a];
});

/// Media-type filter on the source screen (null = all).
final statusKindFilterProvider = NotifierProvider<_KindFilter, MediaKind?>(_KindFilter.new);

class _KindFilter extends Notifier<MediaKind?> {
  @override
  MediaKind? build() => null;
  void set(MediaKind? kind) => state = kind;
}

/// Current statuses for [app]. Invalidate to rescan.
final statusListProvider = FutureProvider.autoDispose
    .family<List<StatusItem>, StatusApp>(
      (ref, app) => ref.watch(statusAccessServiceProvider).listStatuses(app),
    );

final selectedStatusAppProvider =
    NotifierProvider<_SelectedAppNotifier, StatusApp>(_SelectedAppNotifier.new);

class _SelectedAppNotifier extends Notifier<StatusApp> {
  @override
  StatusApp build() => StatusApp.whatsapp;
  void set(StatusApp app) => state = app;
}

/// Source keys of statuses that are already in the library.
final savedSourceKeysProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(appDatabaseProvider).watchSourceKeys(),
);

/// Bounded in-memory cache so scrolling a status grid does not re-decode.
class ThumbnailCache {
  ThumbnailCache({this.maxEntries = 160});
  final int maxEntries;
  final LinkedHashMap<String, Uint8List> _map = LinkedHashMap();

  Uint8List? get(String key) {
    final v = _map.remove(key);
    if (v != null) _map[key] = v;
    return v;
  }

  void put(String key, Uint8List bytes) {
    _map.remove(key);
    _map[key] = bytes;
    while (_map.length > maxEntries) {
      _map.remove(_map.keys.first);
    }
  }

  int get length => _map.length;
}

final thumbnailCacheProvider = Provider<ThumbnailCache>(
  (ref) => ThumbnailCache(),
);

final statusThumbnailProvider = FutureProvider.autoDispose
    .family<Uint8List?, StatusItem>((ref, item) async {
      final cache = ref.watch(thumbnailCacheProvider);
      final cached = cache.get(item.uri);
      if (cached != null) return cached;
      final bytes = await ref
          .watch(mediaToolsProvider)
          .thumbnail(item.uri, item.kind);
      if (bytes != null) cache.put(item.uri, bytes);
      return bytes;
    });
