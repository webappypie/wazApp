// lib/core/services/audio/fake_audio_playback_service.dart
//
// In-memory test fake for AudioPlaybackService (REQ-CLN-01, P-01).
// Provides deterministic playback advancement, state switching, and speed control.

import 'dart:async';
import 'audio_playback_service.dart';

class FakeAudioPlaybackService implements AudioPlaybackService {
  FakeAudioPlaybackService({
    this.defaultDuration = const Duration(seconds: 30),
  });

  final Duration defaultDuration;
  final _controller = StreamController<AudioPlaybackSnapshot>.broadcast();
  Timer? _progressTimer;

  AudioPlaybackSnapshot _snapshot = const AudioPlaybackSnapshot();

  @override
  AudioPlaybackSnapshot get currentSnapshot => _snapshot;

  @override
  Stream<AudioPlaybackSnapshot> get snapshotStream => _controller.stream;

  void _emit(AudioPlaybackSnapshot next) {
    _snapshot = next;
    _controller.add(next);
  }

  @override
  Future<void> play(String contentUri, {Duration? durationHint}) async {
    _progressTimer?.cancel();
    final dur = durationHint ?? defaultDuration;
    _emit(
      _snapshot.copyWith(
        status: AudioPlaybackStatus.playing,
        currentUri: contentUri,
        duration: dur,
        position: Duration.zero,
      ),
    );

    _startTimer();
  }

  void _startTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (_snapshot.status != AudioPlaybackStatus.playing) return;

      final stepMs = (100 * _snapshot.speed).round();
      final nextMs = _snapshot.position.inMilliseconds + stepMs;

      if (nextMs >= _snapshot.duration.inMilliseconds) {
        _progressTimer?.cancel();
        _emit(
          _snapshot.copyWith(
            status: AudioPlaybackStatus.completed,
            position: _snapshot.duration,
          ),
        );
      } else {
        _emit(
          _snapshot.copyWith(
            position: Duration(milliseconds: nextMs),
          ),
        );
      }
    });
  }

  @override
  Future<void> pause() async {
    _progressTimer?.cancel();
    if (_snapshot.status == AudioPlaybackStatus.playing) {
      _emit(_snapshot.copyWith(status: AudioPlaybackStatus.paused));
    }
  }

  @override
  Future<void> resume() async {
    if (_snapshot.status == AudioPlaybackStatus.paused) {
      _emit(_snapshot.copyWith(status: AudioPlaybackStatus.playing));
      _startTimer();
    }
  }

  @override
  Future<void> stop() async {
    _progressTimer?.cancel();
    _emit(
      _snapshot.copyWith(
        status: AudioPlaybackStatus.idle,
        position: Duration.zero,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    final clampedMs = position.inMilliseconds.clamp(0, _snapshot.duration.inMilliseconds);
    _emit(_snapshot.copyWith(position: Duration(milliseconds: clampedMs)));
  }

  @override
  Future<void> setSpeed(double speed) async {
    _emit(_snapshot.copyWith(speed: speed));
  }

  void simulateError(String message) {
    _progressTimer?.cancel();
    _emit(
      _snapshot.copyWith(
        status: AudioPlaybackStatus.error,
        errorMessage: message,
      ),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _controller.close();
  }
}
