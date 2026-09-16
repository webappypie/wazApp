// lib/features/clean/domain/category_data_source.dart
//
// Generic data source contract for category screens (REQ-CLN-01).

import 'category_models.dart';

abstract class CategoryDataSource {
  /// Fetches items for this category.
  Future<List<CategoryItem>> getItems();

  /// Optional stream to watch items if live updates are supported.
  Stream<List<CategoryItem>>? watchItems() => null;
}
