import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/features/editor/domain/edit_state.dart';
import 'package:wazapp/features/video_editor/domain/video_edit_state.dart';

void main() {
  group('clampTrim', () {
    test('keeps values inside the clip', () {
      expect(clampTrim(-500, 99999, 10000, movedStart: true), (start: 0, end: 10000));
    });

    test('enforces the minimum length by pushing the handle that did NOT move', () {
      // user drags the start handle past the end: the end handle is not allowed to move, start stops short
      expect(clampTrim(9900, 10000, 10000, movedStart: true), (start: 9500, end: 10000));
      // user drags the end handle before the start: start stays, end stops at start+min
      expect(clampTrim(0, 100, 10000, movedStart: false), (start: 0, end: kMinTrimMs));
    });

    test('works at the clip boundaries and for clips shorter than the minimum', () {
      expect(clampTrim(0, 0, 10000, movedStart: false), (start: 0, end: kMinTrimMs));
      expect(clampTrim(10000, 10000, 10000, movedStart: true), (start: 10000 - kMinTrimMs, end: 10000));
      expect(clampTrim(0, 200, 200, movedStart: false), (start: 0, end: 200));
    });

    test('result is always a valid range for many inputs', () {
      for (final d in [300, 1000, 12345]) {
        for (var s = -100; s <= d + 100; s += 97) {
          for (var e = -100; e <= d + 100; e += 89) {
            for (final moved in [true, false]) {
              final r = clampTrim(s, e, d, movedStart: moved);
              expect(r.start, inInclusiveRange(0, d));
              expect(r.end, inInclusiveRange(0, d));
              expect(r.end - r.start, greaterThanOrEqualTo(d < kMinTrimMs ? d : kMinTrimMs), reason: '$s $e $d $moved');
            }
          }
        }
      }
    });
  });

  group('output size', () {
    test('even dimensions, never upscaled, quality caps the long side', () {
      expect(outputSize(1920, 1080, CropRect.full, VideoQuality.original), (width: 1920, height: 1080));
      expect(outputSize(1920, 1080, CropRect.full, VideoQuality.p720), (width: 1280, height: 720));
      expect(outputSize(640, 360, CropRect.full, VideoQuality.p1080), (width: 640, height: 360)); // not upscaled
      final odd = outputSize(1001, 1001, CropRect.full, VideoQuality.original);
      expect(odd.width.isEven && odd.height.isEven, isTrue);
    });

    test('portrait sources are capped on the long (vertical) side', () {
      expect(outputSize(1080, 1920, CropRect.full, VideoQuality.p720), (width: 720, height: 1280));
    });

    test('crop reduces the frame; ratio is preserved within rounding; always even', () {
      final s = outputSize(1920, 1080, const CropRect(0.25, 0, 0.75, 1), VideoQuality.original);
      expect(s, (width: 960, height: 1080));
      final sq = outputSize(1920, 1080, const CropRect(0.21875, 0, 0.78125, 1), VideoQuality.p720);
      expect((sq.width / sq.height - 1).abs(), lessThan(0.01));
      expect(sq.width.isEven && sq.height.isEven, isTrue);
    });

    test('8K input is limited to the hardware encoder ceiling', () {
      final s = outputSize(7680, 4320, CropRect.full, VideoQuality.original);
      expect(s.width, 3840);
      expect(s.height, 2160);
    });

    test('bitrate scales with resolution inside bounds', () {
      expect(bitrateFor(1280, 720), lessThan(bitrateFor(1920, 1080)));
      expect(bitrateFor(160, 120), 1500000);
      expect(bitrateFor(3840, 2160), lessThanOrEqualTo(20000000));
    });
  });

  group('planVideoExport', () {
    test('maps every edit into the plan', () {
      final state = VideoEditState(
        trimStartMs: 1000,
        trimEndMs: 6000,
        mute: true,
        quality: VideoQuality.p720,
        visual: const EditState(
          crop: CropRect(0, 0, 0.5, 1),
          overlays: [TextOverlay(id: 't', text: 'नमस्ते')],
        ),
      );
      final plan = planVideoExport(srcWidth: 1920, srcHeight: 1080, state: state);
      expect(plan.startMs, 1000);
      expect(plan.endMs, 6000);
      expect(plan.durationMs, 5000);
      expect(plan.mute, isTrue);
      expect(plan.crop, const CropRect(0, 0, 0.5, 1));
      expect(plan.hasOverlays, isTrue);
      expect((plan.outWidth, plan.outHeight), (960, 1080), reason: "cropped frame is already under the 720p cap");
    });

    test('an untouched edit is a plain full-frame copy re-encode', () {
      final plan = planVideoExport(srcWidth: 1280, srcHeight: 720, state: VideoEditState.initial(8000));
      expect(plan.crop, isNull);
      expect(plan.hasOverlays, isFalse);
      expect(plan.mute, isFalse);
      expect((plan.startMs, plan.endMs), (0, 8000));
      expect(VideoEditState.initial(8000).isUnchangedFor(8000), isTrue);
      expect(VideoEditState.initial(8000).copyWith(mute: true).isUnchangedFor(8000), isFalse);
    });
  });

  group('checkExportedVideo', () {
    final plan = planVideoExport(
      srcWidth: 1280,
      srcHeight: 720,
      state: const VideoEditState(trimStartMs: 0, trimEndMs: 10000),
    );
    String? check({int w = 1280, int h = 720, int d = 10000, bool audio = true, bool srcAudio = true, VideoExportPlan? p}) =>
        checkExportedVideo(p ?? plan, width: w, height: h, durationMs: d, hasAudio: audio, sourceHadAudio: srcAudio);

    test('accepts a matching file, with small container rounding', () {
      expect(check(), isNull);
      expect(check(d: 10300), isNull);
      expect(check(w: 1282), isNull);
    });

    test('rejects unreadable, wrong size, wrong length', () {
      expect(check(d: 0), isNotNull);
      expect(check(w: 0), isNotNull);
      expect(check(w: 640, h: 360), contains('size'));
      expect(check(d: 9000), contains('length'));
      expect(check(d: 11500), contains('length'));
    });

    test('audio state must match the request', () {
      final muted = planVideoExport(
        srcWidth: 1280,
        srcHeight: 720,
        state: const VideoEditState(trimStartMs: 0, trimEndMs: 10000, mute: true),
      );
      expect(check(p: muted, audio: false), isNull);
      expect(check(p: muted, audio: true), contains('sound'));
      expect(check(audio: false), contains('lost'));
      expect(check(audio: false, srcAudio: false), isNull, reason: 'silent source stays silent');
    });
  });
}
