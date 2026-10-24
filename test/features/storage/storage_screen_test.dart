import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/features/storage_manager/presentation/storage_screen.dart';

import '../../support/harness.dart';

var _tick = 0; // strictly increasing save times so "oldest" is well defined

Future<String> addRow(WidgetTester tester, Harness h, String name, List<int> bytes,
    {bool isPrivate = false, String kind = 'image'}) async {
  return (await tester.runAsync(() async {
    final id = h.storage.newId();
    final ext = name.split('.').last;
    final path = isPrivate ? h.storage.privatePath(id, ext) : h.storage.mediaPath(id, ext);
    await File(path).writeAsBytes(bytes);
    await h.db.insertMedia(SavedMediaTableCompanion.insert(
      id: id,
      path: path,
      kind: kind,
      mimeType: kind == 'video' ? 'video/mp4' : 'image/png',
      fileName: name,
      sizeBytes: bytes.length,
      savedAt: DateTime(2026, 10, 25).add(Duration(minutes: _tick++)),
      sourceType: 'imported',
    ));
    await h.db.customStatement('UPDATE saved_media SET is_private = ${isPrivate ? 1 : 0} WHERE id = ?', [id]);
    return id;
  }))!;
}

Widget host(Harness h) => h.wrapRouter([GoRoute(path: '/', builder: (_, _) => const StorageScreen())]);

Future<void> open(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(host(h));
  await h.pumpUntil(tester, () => find.textContaining('used by WazApp').evaluate().isNotEmpty);
  await h.settle(tester, 4);
}

Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 250, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(f);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  const mb = 1024 * 1024;

  testWidgets('summary is measured from disk; private items are an aggregate only and are never named', (tester) async {
    final h = await Harness.create(tester);
    await addRow(tester, h, 'holiday.png', List.filled(2 * mb, 1));
    await addRow(tester, h, 'clip.mp4', List.filled(3 * mb, 2), kind: 'video');
    await addRow(tester, h, 'secret_photo.png', List.filled(1 * mb + 5, 3), isPrivate: true);
    await open(tester, h);

    expect(find.text('6.0 MB'), findsWidgets); // total = 2 + 3 + 1.000005 MB ~ 6.0 MB
    expect(find.textContaining('used by WazApp on this device'), findsOneWidget);
    expect(find.textContaining('Only files WazApp keeps itself are counted'), findsOneWidget);
    expect(find.textContaining('Private Folder: 1 item (details stay hidden here)'), findsOneWidget);
    expect(find.text('secret_photo.png'), findsNothing);
    expect(find.text('holiday.png'), findsOneWidget);
    expect(find.text('clip.mp4'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('duplicate scan explains why items match, selects extras only on request, and deletion needs confirmation', (tester) async {
    final h = await Harness.create(tester);
    final bytes = List.filled(400000, 7);
    // Videos: their tiles open no image file, so Windows cannot hold a lock that would block deleting.
    final keep = await addRow(tester, h, 'original.mp4', bytes, kind: 'video');
    final copy = await addRow(tester, h, 'copy.mp4', bytes, kind: 'video');
    final other = await addRow(tester, h, 'different.mp4', List.filled(400000, 8), kind: 'video');
    await open(tester, h);

    await scrollTo(tester, find.text('Find duplicates'));
    await tester.tap(find.text('Find duplicates'));
    await h.pumpUntil(tester, () => find.text('Identical files').evaluate().isNotEmpty);

    expect(find.text('Identical files'), findsOneWidget);
    expect(find.textContaining('exactly the same content'), findsOneWidget);
    expect(find.textContaining('Could free 391 KB'), findsOneWidget);
    expect(find.textContaining('oldest (suggested to keep)'), findsOneWidget);
    // Nothing is selected or deleted by the scan itself.
    expect(await tester.runAsync(() => h.db.findById(copy)), isNotNull);
    expect(find.textContaining('Delete 1 selected'), findsNothing);

    await scrollTo(tester, find.textContaining('Select extras'));
    await tester.tap(find.textContaining('Select extras (1)'));
    await h.settle(tester, 4);
    await scrollTo(tester, find.textContaining('Delete 1 selected'));
    expect(find.textContaining('Delete 1 selected (391 KB)…'), findsOneWidget);
    await tester.tap(find.textContaining('Delete 1 selected'));
    await h.settle(tester, 6);

    // The confirmation states the count and the size, and cancelling deletes nothing.
    expect(find.text('Delete 1 file?'), findsOneWidget);
    expect(find.textContaining('frees 391 KB'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await h.settle(tester, 6);
    expect(await tester.runAsync(() => h.db.findById(copy)), isNotNull);

    await tester.tap(find.textContaining('Delete 1 selected'));
    await h.settle(tester, 6);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await h.pumpUntil(tester, () => find.textContaining('Deleted 1 file').evaluate().isNotEmpty);

    expect(await tester.runAsync(() => h.db.findById(copy)), isNull);
    expect(await tester.runAsync(() => h.db.findById(keep)), isNotNull, reason: 'the original is kept');
    expect(await tester.runAsync(() => h.db.findById(other)), isNotNull);
    expect(find.text('Identical files'), findsNothing, reason: 'resolved group disappears');
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('private duplicates of a normal item are not reported', (tester) async {
    final h = await Harness.create(tester);
    final bytes = List.filled(5000, 4);
    await addRow(tester, h, 'a.png', bytes);
    await addRow(tester, h, 'hidden_twin.png', bytes, isPrivate: true);
    await open(tester, h);
    await scrollTo(tester, find.text('Find duplicates'));
    await tester.tap(find.text('Find duplicates'));
    await h.pumpUntil(tester, () => find.text('No duplicates found.').evaluate().isNotEmpty);
    expect(find.text('No duplicates found.'), findsOneWidget);
    expect(find.text('hidden_twin.png'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('large files: choose, see the total, confirm with count and size, then delete', (tester) async {
    final h = await Harness.create(tester);
    final big = await addRow(tester, h, 'big.mp4', List.filled(4 * mb, 1), kind: 'video');
    final mid = await addRow(tester, h, 'mid.png', List.filled(2 * mb, 2));
    await open(tester, h);

    await scrollTo(tester, find.text('big.mp4'));
    await tester.tap(find.text('big.mp4'));
    await h.settle(tester, 3);
    await scrollTo(tester, find.textContaining('Delete 1 selected (4.0 MB)…'));
    await tester.tap(find.textContaining('Delete 1 selected'));
    await h.settle(tester, 6);
    expect(find.text('Delete 1 file?'), findsOneWidget);
    expect(find.textContaining('frees 4.0 MB'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await h.pumpUntil(tester, () => find.textContaining('freed 4.0 MB').evaluate().isNotEmpty);

    expect(await tester.runAsync(() => h.db.findById(big)), isNull);
    expect(await tester.runAsync(() => h.db.findById(mid)), isNotNull);
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('clean-up: unreferenced files, temporary files and broken entries each need confirmation', (tester) async {
    final h = await Harness.create(tester);
    final gone = await addRow(tester, h, 'gone.png', List.filled(50, 1));
    await tester.runAsync(() async {
      File((await h.db.findById(gone))!.path).deleteSync();
      File('${h.storage.mediaDir.path}/orphan.jpg').writeAsBytesSync(List.filled(2048, 1));
      Directory('${h.tmp.path}/export_tmp').createSync(recursive: true);
      File('${h.tmp.path}/export_tmp/video_1.mp4').writeAsBytesSync(List.filled(4096, 1));
    });
    await open(tester, h);

    await scrollTo(tester, find.textContaining('1 unreferenced file (2.0 KB)'));
    await tester.tap(find.widgetWithText(TextButton, 'Remove…').first);
    await h.settle(tester, 6);
    expect(find.textContaining('Remove 1 unreferenced file?'), findsOneWidget);
    expect(find.textContaining('frees 2.0 KB'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await h.pumpUntil(tester, () => find.textContaining('Removed 1 file').evaluate().isNotEmpty);
    expect(File('${h.storage.mediaDir.path}/orphan.jpg').existsSync(), isFalse);
    await h.pumpUntil(tester, () => find.textContaining('unreferenced file').evaluate().isEmpty);

    await tester.pump(const Duration(seconds: 5));
    await scrollTo(tester, find.textContaining('Temporary export files (4.0 KB)'));
    await tester.tap(find.text('Clear…'));
    await h.settle(tester, 6);
    expect(find.text('Clear temporary files?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await h.pumpUntil(tester, () => find.textContaining('Freed 4.0 KB').evaluate().isNotEmpty);
    expect(Directory('${h.tmp.path}/export_tmp').listSync(), isEmpty);
    await h.pumpUntil(tester, () => find.textContaining('Temporary export files').evaluate().isEmpty);

    await tester.pump(const Duration(seconds: 5));
    await scrollTo(tester, find.textContaining('1 broken entry'));
    await tester.tap(find.widgetWithText(TextButton, 'Remove…').first);
    await h.settle(tester, 6);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await h.pumpUntil(tester, () => find.textContaining('Removed 1 entry').evaluate().isNotEmpty);
    final snacks = find.byType(SnackBar).evaluate().map((e) => ((e.widget as SnackBar).content as Text).data).toList();
    expect(await tester.runAsync(() => h.db.findById(gone)), isNull, reason: 'snacks: $snacks');
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('an empty WazApp says there is nothing to clean up', (tester) async {
    final h = await Harness.create(tester);
    await open(tester, h);
    expect(find.text('0 B'), findsWidgets);
    await scrollTo(tester, find.textContaining('Nothing to clean up'));
    expect(find.textContaining('No file in your library is larger than 1 MB.'), findsOneWidget);
    await h.dispose(tester);
  });
}
