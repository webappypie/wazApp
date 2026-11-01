// On-device performance probe (Phase 6). Seeds a synthetic library of 720x1280 JPEGs in a temporary
// directory (NOT the app's real library), then measures:
//   - frame build/raster times while flinging through the Saved grid
//   - how long the Storage Manager report and the duplicate scan take
//   - process memory (RSS) before and after
// Run in profile mode for realistic numbers:
//   flutter test integration_test/perf_library_test.dart -d <device> --profile
// Numbers are printed as `PERF ...` lines and copied into docs/audit/PERFORMANCE_REVIEW.md.

import 'dart:io';
import 'dart:math';
import 'dart:ui' show FrameTiming;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/core/design/tokens.dart';
import 'package:wazapp/core/di/providers.dart';
import 'package:wazapp/features/library/data/library_storage.dart';
import 'package:wazapp/features/library/presentation/saved_screen.dart';

const distinct = 120;
const duplicates = 30;

String pct(List<int> sorted, double p) => (sorted[((sorted.length - 1) * p).round()] / 1000).toStringAsFixed(1);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saved grid scroll and storage scans with ${distinct + duplicates} photos', (tester) async {
    final tmp = await (await getTemporaryDirectory()).createTemp('wazapp_perf_');
    final storage = LibraryStorage(Directory('${tmp.path}/support'));
    await storage.ensureCreated();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      await tmp.delete(recursive: true);
    });

    // --- seed ---------------------------------------------------------------------------------------------
    final rng = Random(7);
    final seedWatch = Stopwatch()..start();
    final paths = <String>[];
    await tester.runAsync(() async {
      for (var i = 0; i < distinct; i++) {
        final image = img.Image(width: 720, height: 1280);
        final c1 = img.ColorRgb8(rng.nextInt(256), rng.nextInt(256), rng.nextInt(256));
        final c2 = img.ColorRgb8(rng.nextInt(256), rng.nextInt(256), rng.nextInt(256));
        for (var y = 0; y < 1280; y += 1) {
          final t = y / 1280;
          final row = img.ColorRgb8(
              (c1.r + (c2.r - c1.r) * t).round(), (c1.g + (c2.g - c1.g) * t).round(), (c1.b + (c2.b - c1.b) * t).round());
          for (var x = 0; x < 720; x++) {
            image.setPixel(x, y, row);
          }
        }
        for (var k = 0; k < 8; k++) {
          img.fillCircle(image,
              x: rng.nextInt(720),
              y: rng.nextInt(1280),
              radius: 40 + rng.nextInt(200),
              color: img.ColorRgb8(rng.nextInt(256), rng.nextInt(256), rng.nextInt(256)));
        }
        final id = storage.newId();
        final path = storage.mediaPath(id, 'jpg');
        await File(path).writeAsBytes(img.encodeJpg(image, quality: 82));
        paths.add(path);
        await db.insertMedia(SavedMediaTableCompanion.insert(
          id: id,
          path: path,
          kind: 'image',
          mimeType: 'image/jpeg',
          fileName: 'p$i.jpg',
          sizeBytes: await File(path).length(),
          savedAt: DateTime(2026, 10, 25).add(Duration(minutes: i)),
          sourceType: 'imported',
          width: const Value(720),
          height: const Value(1280),
        ));
      }
      for (var i = 0; i < duplicates; i++) {
        final id = storage.newId();
        final path = storage.mediaPath(id, 'jpg');
        await File(paths[i]).copy(path);
        await db.insertMedia(SavedMediaTableCompanion.insert(
          id: id,
          path: path,
          kind: 'image',
          mimeType: 'image/jpeg',
          fileName: 'dup$i.jpg',
          sizeBytes: await File(path).length(),
          savedAt: DateTime(2026, 10, 26).add(Duration(minutes: i)),
          sourceType: 'imported',
          width: const Value(720),
          height: const Value(1280),
        ));
      }
    });
    final bytes = paths.fold<int>(0, (s, p) => s + File(p).lengthSync());
    // ignore: avoid_print
    print('PERF seeded ${distinct + duplicates} photos, ${(bytes / 1048576).toStringAsFixed(1)} MB distinct, '
        'in ${seedWatch.elapsed.inSeconds} s');

    // --- Saved grid fling ----------------------------------------------------------------------------------
    final frames = <FrameTiming>[];
    void onTimings(List<FrameTiming> t) => frames.addAll(t);
    binding.addTimingsCallback(onTimings);
    final rssBefore = ProcessInfo.currentRss;

    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        libraryStorageProvider.overrideWithValue(storage),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const SavedScreen()),
    ));
    await tester.pump(const Duration(seconds: 2));
    frames.clear();
    for (var i = 0; i < 6; i++) {
      await tester.fling(find.byType(GridView), const Offset(0, -2200), 4500);
      await tester.pump(const Duration(milliseconds: 1500));
    }
    for (var i = 0; i < 6; i++) {
      await tester.fling(find.byType(GridView), const Offset(0, 2200), 4500);
      await tester.pump(const Duration(milliseconds: 1500));
    }
    binding.removeTimingsCallback(onTimings);
    final build = frames.map((f) => f.buildDuration.inMicroseconds).toList()..sort();
    final raster = frames.map((f) => f.rasterDuration.inMicroseconds).toList()..sort();
    final span = frames.map((f) => f.totalSpan.inMicroseconds).toList()..sort();
    final slow = frames.where((f) => f.totalSpan.inMilliseconds > 16).length;
    final jank = frames.where((f) => f.totalSpan.inMilliseconds > 32).length;
    final rssAfter = ProcessInfo.currentRss;
    // ignore: avoid_print
    print('PERF grid frames=${frames.length} build ms p50/p90/p99=${pct(build, .5)}/${pct(build, .9)}/${pct(build, .99)} '
        'raster ms p50/p90/p99=${pct(raster, .5)}/${pct(raster, .9)}/${pct(raster, .99)} '
        'total ms p50/p90/p99/max=${pct(span, .5)}/${pct(span, .9)}/${pct(span, .99)}/${pct(span, 1)} '
        'over16ms=$slow over32ms=$jank');
    // ignore: avoid_print
    print('PERF rss MB before=${(rssBefore / 1048576).toStringAsFixed(0)} after=${(rssAfter / 1048576).toStringAsFixed(0)} '
        'imageCache=${PaintingBinding.instance.imageCache.currentSizeBytes ~/ 1048576} MB '
        '(${PaintingBinding.instance.imageCache.currentSize} images)');
    await tester.pumpWidget(const SizedBox());

    // --- Storage scans -------------------------------------------------------------------------------------
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      libraryStorageProvider.overrideWithValue(storage),
      exportTempDirProvider.overrideWithValue(Directory('${tmp.path}/export_tmp')),
    ]);
    addTearDown(container.dispose);
    final service = container.read(storageServiceProvider);
    await tester.runAsync(() async {
      final w1 = Stopwatch()..start();
      final report = await service.report();
      // ignore: avoid_print
      print('PERF storage report ${w1.elapsedMilliseconds} ms (${report.photos.count} photos)');
      final w2 = Stopwatch()..start();
      final scan = await service.findDuplicates();
      // ignore: avoid_print
      print('PERF duplicate scan (cold) ${w2.elapsed.inMilliseconds} ms, groups=${scan.groups.length} hashed=${scan.filesHashed} fingerprinted=${scan.photosFingerprinted}');
      final w3 = Stopwatch()..start();
      await service.findDuplicates();
      // ignore: avoid_print
      print('PERF duplicate scan (hashes cached) ${w3.elapsed.inMilliseconds} ms');
    });
    // ignore: avoid_print
    print('PERF rss MB end=${(ProcessInfo.currentRss / 1048576).toStringAsFixed(0)}');
  }, timeout: const Timeout(Duration(minutes: 12)));
}
