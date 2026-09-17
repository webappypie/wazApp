// lib/core/services/audio/audio_playback_service.dart
//
// Core abstraction for audio and voice note playback (P-01).
// Provides state, duration, position streams, and controls (play, pause, seek, speed).

import 'dart:async';

enum AudioPlaybackStatus {
  idle,
  playing,
  paused,
  completed,
  error,
}

class AudioPlaybackSnapshot {
  const AudioPlaybackSnapshot({
    this.status = AudioPlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.currentUri,
    this.errorMessage,
  });

  final AudioPlaybackStatus status;
  final Duration position;
  final Duration duration;
  final double speed;
  final String? currentUri;
  final String? errorMessage;

  bool get isPlaying => status == AudioPlaybackStatus.playing;
  bool get isPaused => status == AudioPlaybackStatus.paused;
  bool get isIdle => status == AudioPlaybackStatus.idle;

  double get progressRatio {
    if (duration.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  AudioPlaybackSnapshot copyWith({
    AudioPlaybackStatus? status,
    Duration? position,
    Duration? duration,
    double? speed,
    String? currentUri,
    String? errorMessage,
  }) {
    return AudioPlaybackSnapshot(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      currentUri: currentUri ?? this.currentUri,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

abstract interface class AudioPlaybackService {
  AudioPlaybackSnapshot get currentSnapshot;
  Stream<AudioPlaybackSnapshot> get snapshotStream;

  Future<void> play(String contentUri, {Duration? durationHint});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  void dispose();
}
