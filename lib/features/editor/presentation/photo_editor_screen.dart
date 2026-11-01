// lib/features/editor/presentation/photo_editor_screen.dart
//
// Non-destructive photo editor. The original file is never modified; "Save"
// renders the edit at full resolution into a NEW library item.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/app_error.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../status_maker/domain/status_templates.dart' show containsDevanagari;
import '../data/photo_export_service.dart';
import '../domain/crop_math.dart';
import '../domain/edit_state.dart';
import 'editor_canvas.dart';
import 'editor_panels.dart';
import 'text_input_dialog.dart';

class PhotoEditorScreen extends ConsumerStatefulWidget {
  const PhotoEditorScreen({super.key, required this.mediaId});
  final String mediaId;

  @override
  ConsumerState<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends ConsumerState<PhotoEditorScreen> implements EditorActions {
  final EditHistory<EditState> _history = EditHistory(EditState.initial);
  SavedMedia? _media;
  ui.Image? _preview;
  Object? _loadError;
  bool _loading = true;

  EditorTool _tool = EditorTool.adjust;
  String? _selectedId;
  CropAspect _aspect = CropAspect.free;
  EditState? _gestureFrom;
  int _idCounter = 0;

  static const double _previewMaxDim = 1600;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final media = await ref.read(appDatabaseProvider).findById(widget.mediaId);
      if (media == null || !await File(media.path).exists()) {
        throw const MediaAccessError(MediaFailure.sourceUnavailable, message: 'This photo is no longer available.');
      }
      final bytes = await File(media.path).readAsBytes();
      var target = 0;
      final longest = media.width > media.height ? media.width : media.height;
      if (longest > _previewMaxDim) {
        target = (media.width * _previewMaxDim / longest).round().clamp(1, media.width);
      }
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: target > 0 ? target : null);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _media = media;
        _preview = frame.image;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e;
          _loading = false;
        });
      }
    }
  }

  ui.Size get _source => ui.Size(_preview!.width.toDouble(), _preview!.height.toDouble());

  // ---------------------------------------------------------------------------
  // EditorActions
  // ---------------------------------------------------------------------------

  @override
  EditState get state => _history.present;

  @override
  String? get selectedId => _selectedId;

  @override
  CropAspect get cropAspect => _aspect;

  @override
  void beginGesture() => _gestureFrom = _history.present;

  @override
  void preview(EditState next) => setState(() => _history.preview(next));

  @override
  void commitGesture() {
    final from = _gestureFrom;
    _gestureFrom = null;
    if (from != null) setState(() => _history.commit(from));
  }

  @override
  void push(EditState next) => setState(() => _history.push(next));

  @override
  void select(String? id) => setState(() => _selectedId = id);

  String _newId() => 'o${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  @override
  Future<void> addText() async {
    final text = await _askText(title: 'Add text');
    if (text == null || text.trim().isEmpty || !mounted) return;
    final o = TextOverlay(
      id: _newId(),
      text: text.trim(),
      fontKey: containsDevanagari(text) ? 'hind' : 'poppins',
    );
    setState(() {
      _history.push(state.upsertOverlay(o));
      _selectedId = o.id;
      _tool = EditorTool.text;
    });
  }

  @override
  Future<void> editTextOf(String id) async {
    final t = state.overlays.whereType<TextOverlay>().where((o) => o.id == id).firstOrNull;
    if (t == null) return;
    final text = await _askText(title: 'Edit text', initial: t.text);
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
      _history.push(state.upsertOverlay(o));
      _selectedId = o.id;
    });
  }

  @override
  void setCropAspect(CropAspect a) {
    setState(() {
      _aspect = a;
      final r = aspectRatioFor(a, state.orientedSize(_source));
      if (r != null) {
        _history.push(state.withCrop(aspectCrop(state.orientedSize(_source), r), _source));
      }
    });
  }

  Future<String?> _askText({required String title, String initial = ''}) =>
      TextInputDialog.show(context, title: title, initial: initial);

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final media = _media!;
    final service = ref.read(photoExportServiceProvider);
    final stage = ValueNotifier<ExportStage>(ExportStage.decoding);
    var cancelled = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Saving photo'),
          content: ValueListenableBuilder<ExportStage>(
            valueListenable: stage,
            builder: (_, s, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: (s.index + 1) / ExportStage.values.length),
                const SizedBox(height: 12),
                Text('Step ${s.index + 1} of ${ExportStage.values.length}: ${s.label}…'),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => cancelled = true, child: const Text('Cancel'))],
        ),
      ),
    );

    SavedMedia? saved;
    AppError? error;
    try {
      saved = await service.exportPhoto(
        source: media,
        state: state,
        onStage: (s) => stage.value = s,
        isCancelled: () => cancelled,
      );
    } on OperationCancelled {
      // user cancelled: nothing was saved
    } on AppError catch (e) {
      error = e;
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      stage.dispose();
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (saved != null) {
      // Leave the editor; the original and the new copy are both in Saved.
      final router = GoRouter.of(context);
      router.pop();
      messenger.showSnackBar(SnackBar(
        content: const Text('Saved as a new photo. The original is unchanged.'),
        action: SnackBarAction(label: 'View', onPressed: () => router.go(AppRoutes.saved)),
      ));
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
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Cancelled. Nothing was saved.')));
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_history.isModified) return true;
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
    if (_loadError != null || _preview == null) {
      final msg = _loadError is AppError ? (_loadError as AppError).message : 'This photo could not be opened.';
      return Scaffold(appBar: AppBar(), body: ErrorState(message: msg));
    }
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_history.isModified,
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
          // Four actions leave little room on a 360 dp phone: a smaller title keeps it from collapsing.
          titleSpacing: 0,
          title: const Text('Edit photo', style: AppTextStyles.titleMedium),
          actions: [
            IconButton(
              tooltip: 'Undo',
              icon: const Icon(Icons.undo),
              onPressed: _history.canUndo ? () => setState(_history.undo) : null,
            ),
            IconButton(
              tooltip: 'Redo',
              icon: const Icon(Icons.redo),
              onPressed: _history.canRedo ? () => setState(_history.redo) : null,
            ),
            IconButton(
              tooltip: 'Reset all edits',
              icon: const Icon(Icons.restart_alt),
              onPressed: _history.present == EditState.initial ? null : () => setState(() {
                    _history.reset();
                    _selectedId = null;
                    _aspect = CropAspect.free;
                  }),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilledButton(
                onPressed: _history.present == EditState.initial ? null : _save,
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
                color: scheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: EditorCanvas(
                    image: _preview!,
                    state: state,
                    tool: _tool,
                    selectedId: _selectedId,
                    lockedRatio: aspectRatioFor(_aspect, state.orientedSize(_source)),
                    onPreview: preview,
                    onCommit: (from) => setState(() => _history.commit(from)),
                    onSelect: (id) {
                      setState(() {
                        _selectedId = id;
                        final o = state.overlays.where((x) => x.id == id).firstOrNull;
                        if (o is TextOverlay) _tool = EditorTool.text;
                        if (o is StickerOverlay) _tool = EditorTool.stickers;
                      });
                    },
                  ),
                ),
              ),
            ),
            // Material (not a coloured box) so chip/list ink is visible.
            Material(
              color: scheme.surface,
              child: Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
                child: SingleChildScrollView(child: _panel()),
              ),
            ),
            SafeArea(
              top: false,
              child: Row(
                children: [
                  for (final t in EditorTool.values) Expanded(child: _toolButton(t, scheme)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel() => switch (_tool) {
        EditorTool.adjust => AdjustPanel(actions: this),
        EditorTool.crop => CropPanel(actions: this),
        EditorTool.filters => FilterPanel(actions: this, image: _preview!),
        EditorTool.text => TextPanel(actions: this),
        EditorTool.stickers => StickerPanel(actions: this),
      };

  Widget _toolButton(EditorTool t, ColorScheme scheme) {
    final (icon, label) = switch (t) {
      EditorTool.adjust => (Icons.tune, 'Adjust'),
      EditorTool.crop => (Icons.crop_rotate, 'Crop'),
      EditorTool.filters => (Icons.auto_awesome, 'Filters'),
      EditorTool.text => (Icons.title, 'Text'),
      EditorTool.stickers => (Icons.emoji_emotions_outlined, 'Stickers'),
    };
    final selected = _tool == t;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: () => setState(() {
          _tool = t;
          if (t != EditorTool.text && t != EditorTool.stickers) _selectedId = null;
        }),
        // minHeight (not a fixed height) and a shrinking label so large system text cannot overflow the bar.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      style: AppTextStyles.labelSmall.copyWith(color: selected ? scheme.primary : scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
