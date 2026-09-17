// test/features/clean/video_compression_test.dart
//
// Verification suite for Phase 11: Video Compression (REQ-ACT-09, REQ-CMP-01..04).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wapptidy/core/services/media_access/fake_media_access_service.dart';
import 'package:wapptidy/core/services/media_access/media_item.dart';
import 'package:wapptidy/features/clean/data/media_action_coordinator.dart';
import 'package:wapptidy/features/clean/domain/category_models.dart';
import 'package:wapptidy/features/clean/domain/compression_models.dart';
import 'package:wapptidy/features/clean/presentation/widgets/video_compression_sheet.dart';
import 'package:wapptidy/features/clean/services/video_compression_service.dart';

Widget _buildTestApp({
  required CategoryItem item,
  required VideoCompressionService service,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => VideoCompressionSheet.show(
              context,
              item: item,
              customService: service,
            ),
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleVideo = CategoryItem(
    id: 'vid_1',
    contentUri: 'content://media/videos/1',
    displayName: 'vacation_clip.mp4',
    mimeType: 'video/mp4',
    sizeBytes: 100 * 1024 * 1024, // 100 MB
    dateAddedSec: 1000,
    dateModifiedSec: 1000,
    bucketName: 'WhatsApp Video',
    sourceApp: 'com.whatsapp',
    width: 1920,
    height: 1080,
    durationMs: 60 * 1000, // 60 seconds
  );

  group('REQ-CMP-01 & REQ-CMP-02: Profiles & Size Estimation', () {
    test('Profiles define clear resolution and bitrate constraints', () {
      expect(VideoQualityProfile.balanced.targetHeight, 720);
      expect(VideoQualityProfile.balanced.totalTargetBitrateBps, 2628000);

      expect(VideoQualityProfile.highQuality.targetHeight, 1080);
      expect(VideoQualityProfile.highQuality.totalTargetBitrateBps, 4692000);

      expect(VideoQualityProfile.maximumSavings.targetHeight, 480);
      expect(VideoQualityProfile.maximumSavings.totalTargetBitrateBps, 1096000);
    });

    test('CompressionEstimate calculates bitrate-based savings for 60s video', () {
      final estimate = CompressionEstimate.compute(
        originalBytes: sampleVideo.sizeBytes,
        durationMs: sampleVideo.durationMs,
        profile: VideoQualityProfile.balanced,
      );

      // (2.628 Mbps / 8) * 60s ~ 19.7 MB
      expect(estimate.estimatedBytes, lessThan(sampleVideo.sizeBytes));
      expect(estimate.estimatedSavingsBytes, greaterThan(70 * 1024 * 1024));
      expect(estimate.estimatedSavingsPercentage, greaterThan(70));
    });

    test('CompressionEstimate falls back to profile ratio when durationMs is 0', () {
      final estimate = CompressionEstimate.compute(
        originalBytes: 100 * 1024 * 1024,
        durationMs: 0,
        profile: VideoQualityProfile.highQuality,
      );

      // 70% of 100 MB = 70 MB output, 30 MB savings (30%)
      expect(estimate.estimatedBytes, 70 * 1024 * 1024);
      expect(estimate.estimatedSavingsBytes, 30 * 1024 * 1024);
      expect(estimate.estimatedSavingsPercentage, 30);
    });
  });

  final sampleMediaItem = MediaItem(
    mediaId: 1,
    contentUri: sampleVideo.contentUri,
    mimeType: sampleVideo.mimeType,
    sizeBytes: sampleVideo.sizeBytes,
    dateAddedEpochSec: sampleVideo.dateAddedSec,
    dateModifiedEpochSec: sampleVideo.dateModifiedSec,
    folderBucket: sampleVideo.bucketName,
    source: MediaSource.whatsApp,
  );

  group('REQ-ACT-09 & REQ-CMP-03: Safety Invariants & Replacement Rules', () {
    late FakeMediaAccessService fakeMediaAccess;
    late MediaActionCoordinator actionCoordinator;
    late VideoCompressionService service;

    setUp(() {
      fakeMediaAccess = FakeMediaAccessService()..items.add(sampleMediaItem);
      actionCoordinator = MediaActionCoordinator(mediaAccessService: fakeMediaAccess);
      service = VideoCompressionService(actionCoordinator: actionCoordinator);
    });

    test('Original is NEVER deleted when user chooses Keep Both Files', () async {
      const verifiedResult = CompressionResult(
        originalItem: sampleVideo,
        outputFilePath: '/cache/compressed.mp4',
        originalBytes: 100 * 1024 * 1024,
        compressedBytes: 30 * 1024 * 1024,
        isVerified: true,
        qualityProfile: VideoQualityProfile.balanced,
      );

      final success = await service.finalizeReplacement(
        result: verifiedResult,
        replaceOriginal: false,
      );

      expect(success, isTrue);
      // Original remains completely untouched
      expect(fakeMediaAccess.trashedItems, isEmpty);
    });

    test('Original is moved to bin only when replaceOriginal is true AND verified', () async {
      const verifiedResult = CompressionResult(
        originalItem: sampleVideo,
        outputFilePath: '/cache/compressed.mp4',
        originalBytes: 100 * 1024 * 1024,
        compressedBytes: 30 * 1024 * 1024,
        isVerified: true,
        qualityProfile: VideoQualityProfile.balanced,
      );

      final success = await service.finalizeReplacement(
        result: verifiedResult,
        replaceOriginal: true,
      );

      expect(success, isTrue);
      expect(fakeMediaAccess.trashedItems.map((e) => e.contentUri), [sampleVideo.contentUri]);
    });

    test('Unverified compression result throws StateError and aborts replacement', () async {
      const unverifiedResult = CompressionResult(
        originalItem: sampleVideo,
        outputFilePath: '/cache/partial.mp4',
        originalBytes: 100 * 1024 * 1024,
        compressedBytes: 0,
        isVerified: false,
        qualityProfile: VideoQualityProfile.balanced,
      );

      expect(
        () => service.finalizeReplacement(
          result: unverifiedResult,
          replaceOriginal: true,
        ),
        throwsStateError,
      );

      expect(fakeMediaAccess.trashedItems, isEmpty);
    });
  });

  group('REQ-CMP-04 & UI: VideoCompressionSheet Interaction', () {
    testWidgets('Renders profiles, estimated banner, runs transcode and pops', (tester) async {
      final fakeMediaAccess = FakeMediaAccessService()..items.add(sampleMediaItem);
      final actionCoordinator = MediaActionCoordinator(mediaAccessService: fakeMediaAccess);

      // Mock method channel responses
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.wapptidy/video_compressor'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'compressVideo') {
            return {
              'outputPath': '/data/user/0/cache/comp.mp4',
              'originalBytes': sampleVideo.sizeBytes,
              'compressedBytes': 25 * 1024 * 1024, // 25 MB
              'isVerified': true,
            };
          }
          if (methodCall.method == 'cancelCompression') {
            return null;
          }
          return null;
        },
      );

      final service = VideoCompressionService(actionCoordinator: actionCoordinator);

      await tester.pumpWidget(_buildTestApp(item: sampleVideo, service: service));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Sheet title and file info
      expect(find.text('Compress Video'), findsOneWidget);
      expect(find.text('vacation_clip.mp4'), findsOneWidget);

      // Quality profile options
      expect(find.text('Balanced'), findsOneWidget);
      expect(find.text('High Quality'), findsOneWidget);
      expect(find.text('Maximum Savings'), findsOneWidget);

      // Estimated savings banner
      expect(find.textContaining('Estimated Savings:'), findsOneWidget);

      // Start transcode
      await tester.tap(find.text('Start Compression'));
      await tester.pumpAndSettle();

      // Completion screen displays actual savings
      expect(find.text('Compression Verified!'), findsOneWidget);
      expect(find.textContaining('Actual Savings: 75.0 MB (75%)'), findsOneWidget);

      // User choice buttons
      expect(find.text('Replace Original (Move to Bin)'), findsOneWidget);
      expect(find.text('Keep Both Files'), findsOneWidget);

      // Tap Keep Both Files -> Sheet closes, original kept
      await tester.tap(find.text('Keep Both Files'));
      await tester.pumpAndSettle();

      expect(find.text('Compress Video'), findsNothing);
      expect(fakeMediaAccess.trashedItems, isEmpty);
    });
  });
}
