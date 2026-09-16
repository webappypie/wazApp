// lib/features/clean/data/fake_category_data_source.dart
//
// In-memory fake implementation of CategoryDataSource for tests and previews.

import '../domain/category_data_source.dart';
import '../domain/category_models.dart';

class FakeCategoryDataSource extends CategoryDataSource {
  FakeCategoryDataSource({List<CategoryItem>? items})
      : _items = List<CategoryItem>.from(items ?? _createDefaultItems());

  final List<CategoryItem> _items;

  List<CategoryItem> get currentItems => List.unmodifiable(_items);

  @override
  Future<List<CategoryItem>> getItems() async {
    return List.unmodifiable(_items);
  }

  void setItems(List<CategoryItem> newItems) {
    _items
      ..clear()
      ..addAll(newItems);
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
  }

  void removeItems(Iterable<String> ids) {
    final idSet = ids.toSet();
    _items.removeWhere((item) => idSet.contains(item.id));
  }

  static List<CategoryItem> _createDefaultItems() {
    return [
      const CategoryItem(
        id: 'item_1',
        contentUri: 'content://media/external/images/media/101',
        displayName: 'IMG-20240915-WA0001.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2 * 1024 * 1024, // 2 MB
        dateAddedSec: 1726358400,
        dateModifiedSec: 1726358400,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
        width: 1920,
        height: 1080,
      ),
      const CategoryItem(
        id: 'item_2',
        contentUri: 'content://media/external/video/media/102',
        displayName: 'VID-20240916-WA0002.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 150 * 1024 * 1024, // 150 MB
        dateAddedSec: 1726444800,
        dateModifiedSec: 1726444800,
        bucketName: 'WhatsApp Video',
        sourceApp: 'com.whatsapp',
        width: 1920,
        height: 1080,
        durationMs: 125000,
      ),
      const CategoryItem(
        id: 'item_3',
        contentUri: 'content://media/external/images/media/103',
        displayName: 'Screenshot_20240917-101010.png',
        mimeType: 'image/png',
        sizeBytes: 1024 * 1024, // 1 MB
        dateAddedSec: 1726531200,
        dateModifiedSec: 1726531200,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
        width: 1080,
        height: 2400,
      ),
      const CategoryItem(
        id: 'item_4',
        contentUri: 'content://media/external/audio/media/104',
        displayName: 'AUD-20240917-WA0004.opus',
        mimeType: 'audio/ogg',
        sizeBytes: 512 * 1024, // 512 KB
        dateAddedSec: 1726532000,
        dateModifiedSec: 1726532000,
        bucketName: 'WhatsApp Audio',
        sourceApp: 'com.whatsapp.w4b',
        durationMs: 45000,
      ),
      const CategoryItem(
        id: 'item_5',
        contentUri: 'content://media/external/images/media/105',
        displayName: 'IMG-20230501-WA0005.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 4 * 1024 * 1024, // 4 MB
        dateAddedSec: 1682899200,
        dateModifiedSec: 1682899200,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
        width: 4032,
        height: 3024,
        isProtected: true,
      ),
    ];
  }
}
