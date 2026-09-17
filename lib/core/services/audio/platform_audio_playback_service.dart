// lib/core/services/audio/platform_audio_playback_service.dart
//
// Platform channel implementation of AudioPlaybackService with graceful fallback.

import 'dart:async';
import 'package:flutter/services.dart';

import 'audio_playback_service.dart';
import 'fake_audio_playback_service.dart';

class PlatformAudioPlaybackService implements AudioPlaybackService {
  PlatformAudioPlaybackService({
    MethodChannel? methodChannel,
  })  : _channel = methodChannel ?? const MethodChannel('com.wapptidy/audio_player'),
        _fallback = FakeAudioPlaybackService();

  final MethodChannel _channel;
  final FakeAudioPlaybackService _fallback;
  bool _useFallback = false;

  @override
  AudioPlaybackSnapshot get currentSnapshot => _fallback.currentSnapshot;

  @override
  Stream<AudioPlaybackSnapshot> get snapshotStream => _fallback.snapshotStream;

  @override
  Future<void> play(String contentUri, {Duration? durationHint}) async {
    if (_useFallback) {
      await _fallback.play(contentUri, durationHint: durationHint);
      return;
    }

    try {
      await _channel.invokeMethod<void>('play', {
        'uri': contentUri,
        'durationHintMs': durationHint?.inMilliseconds,
      });
      await _fallback.play(contentUri, durationHint: durationHint);
    } catch (_) {
      _useFallback = true;
      await _fallback.play(contentUri, durationHint: durationHint);
    }
  }

  @override
  Future<void> pause() async {
    if (_useFallback) {
      await _fallback.pause();
      return;
    }
    try {
      await _channel.invokeMethod<void>('pause');
      await _fallback.pause();
    } catch (_) {
      _useFallback = true;
      await _fallback.pause();
    }
  }

  @override
  Future<void> resume() async {
    if (_useFallback) {
      await _fallback.resume();
      return;
    }
    try {
      await _channel.invokeMethod<void>('resume');
      await _fallback.resume();
    } catch (_) {
      _useFallback = true;
      await _fallback.resume();
    }
  }

  @override
  Future<void> stop() async {
    if (_useFallback) {
      await _fallback.stop();
      return;
    }
    try {
      await _channel.invokeMethod<void>('stop');
      await _fallback.stop();
    } catch (_) {
      _useFallback = true;
      await _fallback.stop();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_useFallback) {
      await _fallback.seek(position);
      return;
    }
    try {
      await _channel.invokeMethod<void>('seek', {'positionMs': position.inMilliseconds});
      await _fallback.seek(position);
    } catch (_) {
      _useFallback = true;
      await _fallback.seek(position);
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_useFallback) {
      await _fallback.setSpeed(speed);
      return;
    }
    try {
      await _channel.invokeMethod<void>('setSpeed', {'speed': speed});
      await _fallback.setSpeed(speed);
    } catch (_) {
      _useFallback = true;
      await _fallback.setSpeed(speed);
    }
  }

  @override
  void dispose() {
    _fallback.dispose();
  }
}
