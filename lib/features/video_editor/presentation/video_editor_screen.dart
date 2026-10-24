// lib/features/video_editor/presentation/video_editor_screen.dart
//
// Non-destructive video editor: trim, mute, crop, text/sticker overlays and an
// output size cap. "Save" encodes a NEW file with the native encoder; the
// original is never modified. Only controls that really change the output exist.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/app_error.dart';
import '../../../core/format.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../editor/domain/crop_math.dart';
import '../../editor/domain/edit_state.dart';
import '../../editor/presentation/editor_canvas.dart';
import '../../editor/presentation/editor_panels.dart';
import '../../editor/presentation/text_input_dialog.dart';
import '../../library/domain/library_models.dart';
import '../../status_maker/domain/status_templates.dart' show containsDevanagari;
import '../data/video_export_service.dart';
import '../domain/video_edit_state.dart';

enum _VideoTool { trim, crop, text, stickers, output }

class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({super.key, required this.mediaId});
  final String mediaId;

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> implements EditorActions {
  EditHistory<VideoEditState>? _history;
  SavedMedia? _media;
  VideoPlayerController? _player;
  Object? _loadError;
  bool _loading = true;
  bool _sourceHasAudio = true;

  _VideoTool _tool = _VideoTool.trim;
  String? _selectedId;
  CropAspect _aspect = CropAspect.free;
  VideoEditState? _gestureFrom;
  int _idCounter = 0;

  VideoEditState get _v => _history!.present;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    _player?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    VideoPlayerController? player;
    try {
      final media = await ref.read(appDatabaseProvider).findById(widget.mediaId);
      if (media == null || !await File(media.path).exists()) {
        throw const MediaAccessError(MediaFailure.sourceUnavailable, message: 'This video is no longer available.');
      }
      final info = await ref.read(mediaToolsProvider).describeFile(media.path, MediaKind.video);
      player = VideoPlayerController.file(File(media.path));
      await player.initialize();
      await player.setLooping(false);
      final duration = player.value.duration.inMilliseconds > 0 ? player.value.duration.inMilliseconds : info.durationMs;
      if (duration <= 0 || media.width <= 0) {
        throw const MediaAccessError(MediaFailure.corrupt, message: 'This video cannot be edited.');
      }
      if (!mounted) {
        await player.dispose();
        return;
      }
      player.addListener(_onTick);
      setState(() {
        _media = media;
        _player = player;
        _sourceHasAudio = info.hasAudio;
        _history = EditHistory(VideoEditState.initial(duration));
        _loading = false;
      });
    } catch (e) {
      await player?.dispose();
      if (mounted) {
        setState(() {
          _loadError = e;
          _loading = false;
        });
      }
    }
  }

  /// Keeps playback inside the chosen range.
  void _onTick() {
    final p = _player;
    if (p == null || _history == null) return;
    final pos = p.value.position.inMilliseconds;
    if (p.value.isPlaying && pos >= _v.trimEndMs) {
      p.seekTo(Duration(milliseconds: _v.trimStartMs));
    }
    if (mounted) setState(() {});
  }

  ui.Size get _source => ui.Size(_media!.width.toDouble(), _media!.height.toDouble());

  // ---------------------------------------------------------------------------
  // EditorActions (overlay + crop panels operate on the visual part)
  // ---------------------------------------------------------------------------

  @override
  EditState get state => _v.visual;

  @override
  String? get selectedId => _selectedId;

  @override
  CropAspect get cropAspect => _aspect;

  @override
  void beginGesture() => _gestureFrom = _history!.present;

  @override
  void preview(EditState next) => setState(() => _history!.preview(_v.copyWith(visual: next)));

  @override
  void commitGesture() {
    final from = _gestureFrom;
    _gestureFrom = null;
    if (from != null) setState(() => _history!.commit(from));
  }

  @override
  void push(EditState next) => setState(() => _history!.push(_v.copyWith(visual: next)));

  @override
  void select(String? id) => setState(() => _selectedId = id);

  String _newId() => 'v${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  @override
  Future<void> addText() async {
    final text = await TextInputDialog.show(context, title: 'Add text');
    if (text == null || text.trim().isEmpty || !mounted) return;
    final o = TextOverlay(
      id: _newId(),
      text: text.trim(),
      fontKey: containsDevanagari(text) ? 'hind' : 'poppins',
      sizeFrac: 0.07,
    );
    setState(() {
      _history!.push(_v.copyWith(visual: state.upsertOverlay(o)));
      _selectedId = o.id;
      _tool = _VideoTool.text;
    });
  }

  @override
  Future<void> editTextOf(String id) async {
    final t = state.overlays.whereType<TextOverlay>().where((o) => o.id == id).firstOrNull;
    if (t == null) return;
    final text = await TextInputDialog.show(context, title: 'Edit text', initial: t.text);
    if (text == null || !mounted) return;
    if (text.trim().isEmpty) {
      push(state.removeOverlay(id));
      select(null);
    } else {
      push(state.upsertOverlay(t.copyWith(text: text.trim())));
    }
  }

  @override
  void addSticker(String emoji) {
    final o = StickerOverlay(id: _newId(), emoji: emoji);
    setState(() {
      _history!.push(_v.copyWith(visual: state.upsertOverlay(o)));
      _selectedId = o.id;
    });
  }

  @override
  void setCropAspect(CropAspect a) {
    setState(() {
      _aspect = a;
      final r = aspectRatioFor(a, _source);
      if (r != null) {
        _history!.push(_v.copyWith(visual: state.withCrop(aspectCrop(_source, r), _source)));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Playback + trim
  // ---------------------------------------------------------------------------

  Future<void> _togglePlay() async {
    final p = _player!;
    if (p.value.isPlaying) {
      await p.pause();
    } else {
      final pos = p.value.position.inMilliseconds;
      if (pos < _v.trimStartMs || pos >= _v.trimEndMs - 50) {
        await p.seekTo(Duration(milliseconds: _v.trimStartMs));
      }
      await p.play();
    }
  }

  void _onTrimChanged(RangeValues values, {required bool movedStart}) {
    final d = _player!.value.duration.inMilliseconds;
    final r = clampTrim(values.start.round(), values.end.round(), d, movedStart: movedStart);
    setState(() => _history!.preview(_v.copyWith(trimStartMs: r.start, trimEndMs: r.end)));
    _player!.seekTo(Duration(milliseconds: movedStart ? r.start : (r.end - 300).clamp(r.start, r.end)));
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final media = _media!;
    final service = ref.read(videoExportServiceProvider);
    await _player?.pause();
    if (!mounted) return;
    final stage = ValueNotifier<VideoExportStage>(VideoExportStage.preparing);
    final progress = ValueNotifier<double?>(null);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Saving video'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, p, _) => ValueListenableBuilder<VideoExportStage>(
              valueListenable: stage,
              builder: (_, s, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: s == VideoExportStage.encoding ? p : null),
                  const SizedBox(height: 12),
                  Text(s == VideoExportStage.encoding && p != null
                      ? '${s.label}… ${(p * 100).round()}%'
                      : '${s.label}…'),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: service.cancel, child: const Text('Cancel'))],
        ),
      ),
    );

    SavedMedia? saved;
    AppError? error;
    var cancelled = false;
    try {
      saved = await service.exportVideo(
        source: media,
        state: _v,
        sourceHasAudio: _sourceHasAudio,
        onStage: (s) => stage.value = s,
        onProgress: (p) => progress.value = p,
      );
    } on OperationCancelled {
      cancelled = true;
    } on AppError catch (e) {
      error = e;
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      stage.dispose();
      progress.dispose();
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (saved != null) {
      final router = GoRouter.of(context);
      router.pop();
      messenger.showSnackBar(SnackBar(
        content: const Text('Saved as a new video. The original is unchanged.'),
        action: SnackBarAction(label: 'View', onPressed: () => router.go(AppRoutes.saved)),
      ));
    } else if (cancelled) {
      messenger.showSnackBar(const SnackBar(content: Text('Cancelled. Nothing was saved.')));
    } else if (error != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Could not save'),
          content: Text(error!.message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _save();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!(_history?.isModified ?? false)) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits have not been saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return ok ?? false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null || _player == null || _history == null) {
      final msg = _loadError is AppError ? (_loadError as AppError).message : 'This video could not be opened.';
      return Scaffold(appBar: AppBar(), body: ErrorState(message: msg));
    }
    final scheme = Theme.of(context).colorScheme;
    final modified = _history!.isModified;
    return PopScope(
      canPop: !modified,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close editor',
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _confirmDiscard() && context.mounted) context.pop();
            },
          ),
          title: const Text('Edit video'),
          actions: [
            IconButton(
              tooltip: 'Undo',
              icon: const Icon(Icons.undo),
              onPressed: _history!.canUndo ? () => setState(_history!.undo) : null,
            ),
            IconButton(
              tooltip: 'Redo',
              icon: const Icon(Icons.redo),
              onPressed: _history!.canRedo ? () => setState(_history!.redo) : null,
            ),
            IconButton(
              tooltip: 'Reset all edits',
              icon: const Icon(Icons.restart_alt),
              onPressed: modified
                  ? () => setState(() {
                        _history!.reset();
                        _selectedId = null;
                        _aspect = CropAspect.free;
                      })
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilledButton(
                onPressed: modified ? _save : null,
                style: FilledButton.styleFrom(minimumSize: const Size(72, 40)),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: Colors.black,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: EditorCanvas(
                    sourceSize: _source,
                    state: state,
                    tool: _tool == _VideoTool.crop ? EditorTool.crop : EditorTool.text,
                    selectedId: _selectedId,
                    lockedRatio: aspectRatioFor(_aspect, _source),
                    baseBuilder: _videoBase,
                    onPreview: preview,
                    onCommit: (from) => setState(() => _history!.commit(_v.copyWith(visual: from))),
                    onSelect: (id) => setState(() {
                      _selectedId = id;
                      final o = state.overlays.where((x) => x.id == id).firstOrNull;
                      if (o is TextOverlay) _tool = _VideoTool.text;
                      if (o is StickerOverlay) _tool = _VideoTool.stickers;
                    }),
                  ),
                ),
              ),
            ),
            _transport(scheme),
            // Material (not a coloured box) so chip/list ink is visible.
            Material(
              color: scheme.surface,
              child: Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 0),
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.36),
                child: SingleChildScrollView(child: _panel()),
              ),
            ),
            SafeArea(
              top: false,
              child: Row(children: [for (final t in _VideoTool.values) Expanded(child: _toolButton(t, scheme))]),
            ),
          ],
        ),
      ),
    );
  }

  /// The video, positioned so the crop window fills the frame (whole video while cropping).
  Widget _videoBase(BuildContext context, Size frame, EditState s, bool cropping) {
    final crop = cropping ? CropRect.full : s.crop;
    final fullW = frame.width / crop.width;
    final fullH = frame.height / crop.height;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: fullW,
        maxWidth: fullW,
        minHeight: fullH,
        maxHeight: fullH,
        child: Transform.translate(
          offset: Offset(-crop.left * fullW, -crop.top * fullH),
          child: SizedBox(width: fullW, height: fullH, child: VideoPlayer(_player!)),
        ),
      ),
    );
  }

  Widget _transport(ColorScheme scheme) {
    final p = _player!;
    final playing = p.value.isPlaying;
    final pos = p.value.position.inMilliseconds.clamp(_v.trimStartMs, _v.trimEndMs);
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: playing ? 'Pause' : 'Play',
            icon: Icon(playing ? Icons.pause_circle : Icons.play_circle, size: 36),
            onPressed: _togglePlay,
          ),
          Text(
            '${formatDuration(Duration(milliseconds: pos - _v.trimStartMs))} / ${formatDuration(Duration(milliseconds: _v.trimmedMs))}',
            style: AppTextStyles.labelLarge,
          ),
          const Spacer(),
          if (_v.mute) const Icon(Icons.volume_off, size: 20) else const Icon(Icons.volume_up, size: 20),
        ],
      ),
    );
  }

  Widget _panel() => switch (_tool) {
        _VideoTool.trim => _trimPanel(),
        _VideoTool.crop => CropPanel(actions: this, showOrientation: false),
        _VideoTool.text => TextPanel(actions: this),
        _VideoTool.stickers => StickerPanel(actions: this),
        _VideoTool.output => _outputPanel(),
      };

  Widget _trimPanel() {
    final d = _player!.value.duration.inMilliseconds.toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RangeSlider(
          values: RangeValues(_v.trimStartMs.toDouble(), _v.trimEndMs.toDouble()),
          min: 0,
          max: d,
          labels: RangeLabels(
            formatDuration(Duration(milliseconds: _v.trimStartMs)),
            formatDuration(Duration(milliseconds: _v.trimEndMs)),
          ),
          onChangeStart: (_) => beginGesture(),
          onChanged: (v) => _onTrimChanged(v, movedStart: (v.start - _v.trimStartMs).abs() > (v.end - _v.trimEndMs).abs()),
          onChangeEnd: (_) => commitGesture(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Start ${formatDuration(Duration(milliseconds: _v.trimStartMs))}', style: AppTextStyles.labelMedium),
            Text('Length ${formatDuration(Duration(milliseconds: _v.trimmedMs))}', style: AppTextStyles.labelLarge),
            Text('End ${formatDuration(Duration(milliseconds: _v.trimEndMs))}', style: AppTextStyles.labelMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _outputPanel() {
    final m = _media!;
    final longSide = m.width > m.height ? m.width : m.height;
    // Only caps that really shrink this video are offered.
    final options = [
      VideoQuality.original,
      for (final q in [VideoQuality.p1080, VideoQuality.p720])
        if (q.maxLongSide! < longSide) q,
    ];
    final plan = planVideoExport(srcWidth: m.width, srcHeight: m.height, state: _v);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mute audio'),
          subtitle: Text(_sourceHasAudio ? 'Removes the sound from the saved video' : 'This video has no sound'),
          value: _v.mute && _sourceHasAudio,
          onChanged: _sourceHasAudio
              ? (v) => setState(() => _history!.push(_v.copyWith(mute: v)))
              : null,
        ),
        Text('Size', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final q in options)
              ChoiceChip(
                label: Text(q.label),
                selected: _v.quality == q || (!options.contains(_v.quality) && q == VideoQuality.original),
                onSelected: (_) => setState(() => _history!.push(_v.copyWith(quality: q))),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Saved as MP4 (H.264), ${plan.outWidth} × ${plan.outHeight}.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _toolButton(_VideoTool t, ColorScheme scheme) {
    final (icon, label) = switch (t) {
      _VideoTool.trim => (Icons.content_cut, 'Trim'),
      _VideoTool.crop => (Icons.crop, 'Crop'),
      _VideoTool.text => (Icons.title, 'Text'),
      _VideoTool.stickers => (Icons.emoji_emotions_outlined, 'Stickers'),
      _VideoTool.output => (Icons.tune, 'Output'),
    };
    final selected = _tool == t;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: () => setState(() {
          _tool = t;
          if (t != _VideoTool.text && t != _VideoTool.stickers) _selectedId = null;
        }),
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              Text(label,
                  style: AppTextStyles.labelSmall.copyWith(color: selected ? scheme.primary : scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
