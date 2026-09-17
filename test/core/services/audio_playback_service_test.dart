// test/core/services/audio_playback_service_test.dart
//
// Verification for AudioPlaybackService (P-01 safe verification before deletion).

import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/services/audio/audio_playback_service.dart';
import 'package:wapptidy/core/services/audio/fake_audio_playback_service.dart';

void main() {
  late FakeAudioPlaybackService player;

  setUp(() {
    player = FakeAudioPlaybackService(defaultDuration: const Duration(seconds: 10));
  });

  tearDown(() {
    player.dispose();
  });

  group('P-01: AudioPlaybackService Core Operations', () {
    test('Starts in idle state with zero position', () {
      expect(player.currentSnapshot.status, AudioPlaybackStatus.idle);
      expect(player.currentSnapshot.position, Duration.zero);
      expect(player.currentSnapshot.isPlaying, isFalse);
    });

    test('play() updates status to playing and emits snapshots', () async {
      await player.play('content://media/audio/1', durationHint: const Duration(seconds: 20));

      expect(player.currentSnapshot.status, AudioPlaybackStatus.playing);
      expect(player.currentSnapshot.currentUri, 'content://media/audio/1');
      expect(player.currentSnapshot.duration, const Duration(seconds: 20));
      expect(player.currentSnapshot.isPlaying, isTrue);
    });

    test('pause() and resume() cycle playback status', () async {
      await player.play('content://media/audio/1');
      expect(player.currentSnapshot.isPlaying, isTrue);

      await player.pause();
      expect(player.currentSnapshot.status, AudioPlaybackStatus.paused);
      expect(player.currentSnapshot.isPaused, isTrue);

      await player.resume();
      expect(player.currentSnapshot.status, AudioPlaybackStatus.playing);
    });

    test('seek() updates playback position within duration bounds', () async {
      await player.play('content://media/audio/1', durationHint: const Duration(seconds: 30));

      await player.seek(const Duration(seconds: 15));
      expect(player.currentSnapshot.position, const Duration(seconds: 15));
      expect(player.currentSnapshot.progressRatio, closeTo(0.5, 0.01));

      // Exceeding duration clamps to duration
      await player.seek(const Duration(seconds: 50));
      expect(player.currentSnapshot.position, const Duration(seconds: 30));
    });

    test('setSpeed() updates playback rate', () async {
      await player.setSpeed(1.5);
      expect(player.currentSnapshot.speed, 1.5);

      await player.setSpeed(2.0);
      expect(player.currentSnapshot.speed, 2.0);
    });

    test('stop() resets playback to idle and zero position', () async {
      await player.play('content://media/audio/1');
      await player.seek(const Duration(seconds: 5));

      await player.stop();
      expect(player.currentSnapshot.status, AudioPlaybackStatus.idle);
      expect(player.currentSnapshot.position, Duration.zero);
    });

    test('simulateError() sets error state and message', () {
      player.simulateError('Audio codec unsupported');

      expect(player.currentSnapshot.status, AudioPlaybackStatus.error);
      expect(player.currentSnapshot.errorMessage, 'Audio codec unsupported');
    });
  });
}
