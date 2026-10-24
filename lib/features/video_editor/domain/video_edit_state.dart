// lib/features/video_editor/domain/video_edit_state.dart
//
// Non-destructive description of a video edit plus the pure planning/validation
// logic around it (no platform code, fully unit-tested).
//
// Only edits the native encoder really performs are modelled: trim, mute, crop,
// text/sticker overlays and an output size cap.

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../../editor/domain/edit_state.dart';

/// Shortest clip we allow after trimming.
const int kMinTrimMs = 500;

/// Output size options. Only options that are smaller than the source are offered.
enum VideoQuality {
  original('Original', null),
  p1080('1080p', 1920),
  p720('720p', 1280);

  const VideoQuality(this.label, this.maxLongSide);
  final String label;

  /// Longest side in pixels, or null for "keep the source size".
  final int? maxLongSide;
}

/// Hard ceiling even for "Original" (hardware H.264 encoders commonly stop at 4K).
const int kMaxEncodeLongSide = 3840;

class VideoEditState extends Equatable {
  const VideoEditState({
    required this.trimStartMs,
    required this.trimEndMs,
    this.mute = false,
    this.quality = VideoQuality.original,
    this.visual = EditState.initial,
  });

  /// Whole clip, nothing changed.
  factory VideoEditState.initial(int durationMs) =>
      VideoEditState(trimStartMs: 0, trimEndMs: durationMs);

  final int trimStartMs;
  final int trimEndMs;
  final bool mute;
  final VideoQuality quality;

  /// Crop + overlays (rotation/flip are not used for video).
  final EditState visual;

  int get trimmedMs => trimEndMs - trimStartMs;

  VideoEditState copyWith({
    int? trimStartMs,
    int? trimEndMs,
    bool? mute,
    VideoQuality? quality,
    EditState? visual,
  }) =>
      VideoEditState(
        trimStartMs: trimStartMs ?? this.trimStartMs,
        trimEndMs: trimEndMs ?? this.trimEndMs,
        mute: mute ?? this.mute,
        quality: quality ?? this.quality,
        visual: visual ?? this.visual,
      );

  /// Same trim, mute, quality and visuals as [other]'s initial for a clip of [durationMs]?
  bool isUnchangedFor(int durationMs) => this == VideoEditState.initial(durationMs);

  @override
  List<Object?> get props => [trimStartMs, trimEndMs, mute, quality, visual];
}

/// Clamps a trim to the clip and enforces [kMinTrimMs]. [movedStart] says which handle moved,
/// so the other one is pushed rather than the moved one being refused.
({int start, int end}) clampTrim(int start, int end, int durationMs, {required bool movedStart}) {
  var s = start.clamp(0, durationMs);
  var e = end.clamp(0, durationMs);
  final minLen = math.min(kMinTrimMs, durationMs);
  if (e - s < minLen) {
    if (movedStart) {
      s = (e - minLen).clamp(0, durationMs);
      if (e - s < minLen) e = (s + minLen).clamp(0, durationMs);
    } else {
      e = (s + minLen).clamp(0, durationMs);
      if (e - s < minLen) s = (e - minLen).clamp(0, durationMs);
    }
  }
  return (start: s, end: e);
}

/// Everything the encoder is told to do, derived from the edit.
class VideoExportPlan extends Equatable {
  const VideoExportPlan({
    required this.startMs,
    required this.endMs,
    required this.outWidth,
    required this.outHeight,
    required this.crop,
    required this.mute,
    required this.hasOverlays,
    required this.videoBitrate,
  });

  final int startMs;
  final int endMs;
  final int outWidth;
  final int outHeight;

  /// Null when the whole frame is kept.
  final CropRect? crop;
  final bool mute;
  final bool hasOverlays;
  final int videoBitrate;

  int get durationMs => endMs - startMs;

  @override
  List<Object?> get props => [startMs, endMs, outWidth, outHeight, crop, mute, hasOverlays, videoBitrate];
}

int _even(double v) => math.max(2, (v / 2).round() * 2);

/// Output frame size for an upright [srcWidth]x[srcHeight] source after [crop] and [quality].
({int width, int height}) outputSize(int srcWidth, int srcHeight, CropRect crop, VideoQuality quality) {
  final fw = srcWidth * crop.width;
  final fh = srcHeight * crop.height;
  final cap = math.min(quality.maxLongSide ?? kMaxEncodeLongSide, kMaxEncodeLongSide).toDouble();
  final k = math.min(1.0, cap / math.max(fw, fh));
  return (width: _even(fw * k), height: _even(fh * k));
}

/// H.264 bitrate: ~0.09 bits per pixel per frame at 30 fps, bounded to a sane range.
int bitrateFor(int width, int height) => (width * height * 30 * 0.09).round().clamp(1500000, 20000000);

VideoExportPlan planVideoExport({
  required int srcWidth,
  required int srcHeight,
  required VideoEditState state,
}) {
  final crop = state.visual.crop;
  final size = outputSize(srcWidth, srcHeight, crop, state.quality);
  return VideoExportPlan(
    startMs: state.trimStartMs,
    endMs: state.trimEndMs,
    outWidth: size.width,
    outHeight: size.height,
    crop: crop.isFull ? null : crop,
    mute: state.mute,
    hasOverlays: state.visual.overlays.isNotEmpty,
    videoBitrate: bitrateFor(size.width, size.height),
  );
}

/// What a finished file must look like. Returns a user-facing problem or null if it matches the plan.
String? checkExportedVideo(
  VideoExportPlan plan, {
  required int width,
  required int height,
  required int durationMs,
  required bool hasAudio,
  required bool sourceHadAudio,
}) {
  if (width <= 0 || height <= 0 || durationMs <= 0) {
    return 'The exported video is not readable.';
  }
  if ((width - plan.outWidth).abs() > 2 || (height - plan.outHeight).abs() > 2) {
    return 'The exported video has an unexpected size.';
  }
  final tolerance = math.max(500, (plan.durationMs * 0.05).round());
  if ((durationMs - plan.durationMs).abs() > tolerance) {
    return 'The exported video has an unexpected length.';
  }
  if (plan.mute && hasAudio) return 'The exported video still has sound.';
  if (!plan.mute && sourceHadAudio && !hasAudio) return 'The exported video lost its sound.';
  return null;
}
