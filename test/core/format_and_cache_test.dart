import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/core/format.dart';
import 'package:wazapp/features/status/domain/status_models.dart';
import 'package:wazapp/features/status/presentation/status_providers.dart';
import 'package:wazapp/features/library/domain/library_models.dart';

void main() {
  test('formatBytes', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1023), '1023 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(formatBytes(150 * 1024 * 1024), '150 MB');
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
    expect(formatDuration(const Duration(seconds: 75)), '1:15');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  test('formatRelativeDate', () {
    final now = DateTime(2026, 10, 24, 15);
    expect(formatRelativeDate(DateTime(2026, 10, 24, 1), now: now), 'Today');
    expect(formatRelativeDate(DateTime(2026, 10, 23, 23), now: now), 'Yesterday');
    expect(formatRelativeDate(DateTime(2026, 10, 20), now: now), '4 days ago');
    expect(formatRelativeDate(DateTime(2026, 9, 1), now: now), '1 Sep 2026');
  });

  test('ThumbnailCache is bounded and evicts least recently used', () {
    final c = ThumbnailCache(maxEntries: 2);
    c.put('a', Uint8List(1));
    c.put('b', Uint8List(1));
    expect(c.get('a'), isNotNull); // a becomes most recent
    c.put('c', Uint8List(1)); // evicts b
    expect(c.length, 2);
    expect(c.get('b'), isNull);
    expect(c.get('a'), isNotNull);
    expect(c.get('c'), isNotNull);
  });

  test('StatusItem identity separates apps and sizes; extension falls back by kind', () {
    final base = StatusItem(
      app: StatusApp.whatsapp,
      uri: 'u',
      name: 'abc.JPG',
      kind: MediaKind.image,
      mimeType: 'image/jpeg',
      sizeBytes: 10,
      modified: DateTime(2026),
    );
    expect(base.sourceKey, 'whatsapp:abc.JPG:10');
    expect(base.extension, 'jpg');
    final biz = StatusItem(
      app: StatusApp.business,
      uri: 'u',
      name: 'abc.JPG',
      kind: MediaKind.image,
      mimeType: 'image/jpeg',
      sizeBytes: 10,
      modified: DateTime(2026),
    );
    expect(biz.sourceKey, isNot(base.sourceKey));
    final noExt = StatusItem(
      app: StatusApp.whatsapp,
      uri: 'u',
      name: 'noext',
      kind: MediaKind.video,
      mimeType: 'video/mp4',
      sizeBytes: 1,
      modified: DateTime(2026),
    );
    expect(noExt.extension, 'mp4');
    expect(StatusApp.fromKey('business'), StatusApp.business);
    expect(StatusApp.fromKey('x'), isNull);
  });
}
