// test/features/clean/voice_notes_test.dart
//
// Verification for VoiceNotesDataSource and VoiceNotesScreen (REQ-CLN-01, P-01).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/core/services/audio/fake_audio_playback_service.dart';
import 'package:wapptidy/core/services/media_access/fake_media_access_service.dart';
import 'package:wapptidy/features/clean/data/media_action_coordinator.dart';
import 'package:wapptidy/features/clean/data/voice_notes_data_source.dart';
import 'package:wapptidy/features/clean/domain/category_models.dart';
import 'package:wapptidy/features/clean/presentation/voice_notes_screen.dart';

void main() {
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final sampleItems = [
    CategoryItem(
      id: '1',
      contentUri: 'content://media/audio/1',
      displayName: 'PTT-20230501-WA0001.opus',
      mimeType: 'audio/ogg',
      sizeBytes: 500 * 1024,
      dateAddedSec: nowSec - 200 * 86400,
      dateModifiedSec: nowSec - 200 * 86400,
      bucketName: 'WhatsApp Voice Notes',
      sourceApp: 'com.whatsapp',
      durationMs: 45000,
    ),
    CategoryItem(
      id: '2',
      contentUri: 'content://media/audio/2',
      displayName: 'AUD-20230601-WA0002.mp3',
      mimeType: 'audio/mpeg',
      sizeBytes: 8 * 1024 * 1024,
      dateAddedSec: nowSec - 50 * 86400,
      dateModifiedSec: nowSec - 50 * 86400,
      bucketName: 'WhatsApp Audio',
      sourceApp: 'com.whatsapp',
      durationMs: 240000,
    ),
    CategoryItem(
      id: '3',
      contentUri: 'content://media/audio/3',
      displayName: 'PTT-20230701-WA0003.opus',
      mimeType: 'audio/ogg',
      sizeBytes: 150 * 1024,
      dateAddedSec: nowSec - 10 * 86400,
      dateModifiedSec: nowSec - 10 * 86400,
      bucketName: 'WhatsApp Voice Notes',
      sourceApp: 'com.whatsapp',
      durationMs: 12000,
      isProtected: true, // Should be excluded from cleanup
    ),
  ];

  group('VoiceNotesDataSource Unit Tests', () {
    test('Correctly separates Voice Notes (PTT) vs Audio Clips', () async {
      final ds = VoiceNotesDataSource(testItems: sampleItems);
      final items = await ds.getItems();

      // Item 3 is protected so only items 1 & 2 are returned
      expect(items.length, 2);

      final pttItem = items.firstWhere((i) => i.id == '1');
      expect(pttItem.badgeLabel, 'Voice Note');
      expect(pttItem.groupTitle, 'Voice Notes');
      expect(VoiceNotesDataSource.isVoiceNote(pttItem), isTrue);
      expect(VoiceNotesDataSource.isAudioClip(pttItem), isFalse);

      final audioItem = items.firstWhere((i) => i.id == '2');
      expect(audioItem.badgeLabel, 'Audio Clip');
      expect(audioItem.groupTitle, 'Audio Clips');
      expect(VoiceNotesDataSource.isAudioClip(audioItem), isTrue);
      expect(VoiceNotesDataSource.isVoiceNote(audioItem), isFalse);
    });
  });

  group('VoiceNotesScreen UI Tests', () {
    late FakeMediaAccessService fakeMedia;
    late FakeAudioPlaybackService fakeAudio;

    setUp(() {
      fakeMedia = FakeMediaAccessService();
      fakeAudio = FakeAudioPlaybackService();
    });

    tearDown(() {
      fakeAudio.dispose();
    });

    Widget buildTestScreen() {
      return ProviderScope(
        overrides: [
          mediaAccessServiceProvider.overrideWithValue(fakeMedia),
          audioPlaybackServiceProvider.overrideWithValue(fakeAudio),
          mediaActionCoordinatorProvider.overrideWithValue(
            MediaActionCoordinator(mediaAccessService: fakeMedia),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: VoiceNotesScreen(
            dataSourceOverride: VoiceNotesDataSource(testItems: sampleItems),
          ),
        ),
      );
    }

    testWidgets('Renders header, total space, and audio list items', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('Voice Notes & Audio'), findsOneWidget);
      expect(find.textContaining('Total Space:'), findsOneWidget);
      expect(find.text('PTT-20230501-WA0001.opus'), findsOneWidget);
      expect(find.text('AUD-20230601-WA0002.mp3'), findsOneWidget);
      expect(find.text('Voice Note'), findsOneWidget);
      expect(find.text('Audio Clip'), findsOneWidget);
    });

    testWidgets('Tapping item opens MediaPreviewSheet with audio player', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Tap the first voice note
      await tester.tap(find.text('PTT-20230501-WA0001.opus'));
      await tester.pumpAndSettle();

      // Verify audio player card in modal sheet
      expect(find.text('Voice Note Preview'), findsOneWidget);
      expect(find.text('Play Audio'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);

      // Tap Play Audio
      await tester.tap(find.text('Play Audio'));
      await tester.pump();

      expect(fakeAudio.currentSnapshot.isPlaying, isTrue);

      // Tap Pause Audio to stop the progress timer
      await tester.tap(find.text('Pause Audio'));
      await tester.pump();
      expect(fakeAudio.currentSnapshot.isPaused, isTrue);

      // Close modal sheet
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });
  });
}
