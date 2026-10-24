// lib/features/library/presentation/library_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../domain/library_models.dart';

/// All ordinary library items, newest first, live from the database.
final libraryItemsProvider = StreamProvider<List<SavedMedia>>(
  (ref) => ref.watch(appDatabaseProvider).watchLibrary(),
);

final libraryFilterProvider =
    NotifierProvider<_FilterNotifier, LibraryFilter>(_FilterNotifier.new);

class _FilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => LibraryFilter.all;
  void set(LibraryFilter f) => state = f;
}

final libraryQueryProvider = NotifierProvider<_QueryNotifier, String>(_QueryNotifier.new);

class _QueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q;
}

/// Items after the active filter chip and search text are applied.
final visibleLibraryProvider = Provider<AsyncValue<List<SavedMedia>>>((ref) {
  final items = ref.watch(libraryItemsProvider);
  final filter = ref.watch(libraryFilterProvider);
  final query = ref.watch(libraryQueryProvider);
  return items.whenData((list) => applyLibraryFilter(list, filter: filter, query: query));
});
