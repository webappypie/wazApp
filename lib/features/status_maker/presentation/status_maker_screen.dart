// lib/features/status_maker/presentation/status_maker_screen.dart
//
// Create a text status in Hindi or English from distinct templates.
// The preview uses the same painter as the exported 1080x1920 image.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/app_error.dart';
import '../../../core/router/app_router.dart';
import '../../editor/domain/edit_state.dart';
import '../../editor/presentation/editor_panels.dart' show kSwatches;
import '../../library/presentation/library_actions.dart';
import '../data/status_export_service.dart';
import '../domain/status_renderer.dart';
import '../domain/status_templates.dart';

final statusExportServiceProvider = Provider<StatusExportService>(
  (ref) => StatusExportService(
    library: ref.watch(libraryServiceProvider),
    tempDir: ref.watch(exportTempDirProvider),
  ),
);

class StatusMakerScreen extends ConsumerStatefulWidget {
  const StatusMakerScreen({super.key});

  @override
  ConsumerState<StatusMakerScreen> createState() => _StatusMakerScreenState();
}

class _StatusMakerScreenState extends ConsumerState<StatusMakerScreen> {
  StatusLanguage _lang = StatusLanguage.english;
  late StatusDraft _draft;
  late final TextEditingController _text;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = kStatusTemplates.first;
    _text = TextEditingController(text: sampleFor(t, _lang));
    _draft = StatusDraft(templateId: t.id, text: _text.text);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _update(StatusDraft d) => setState(() => _draft = d);

  void _pickTemplate(StatusTemplate t) {
    // Replace the text only if the user has not typed their own.
    final replace = isSampleText(_text.text);
    if (replace) _text.text = sampleFor(t, _lang);
    _update(_draft.copyWith(templateId: t.id, text: _text.text, clearOverrides: true));
  }

  void _pickLanguage(StatusLanguage l) {
    setState(() {
      _lang = l;
      if (isSampleText(_text.text)) {
        _text.text = sampleFor(_draft.template, l);
        _draft = _draft.copyWith(text: _text.text);
      }
    });
  }

  Future<void> _save({required bool share}) async {
    if (_saving) return;
    if (_text.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Type a message first.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref.read(statusExportServiceProvider).export(_draft);
      if (!mounted) return;
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Saved to your library'),
          action: SnackBarAction(label: 'View', onPressed: () => router.go(AppRoutes.saved)),
        ));
      if (share) await shareMedia(context, [saved]);
    } on AppError catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Could not save'),
          content: Text(e.message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _save(share: share);
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = _draft.template;
    final fontKey = _draft.fontKey ?? t.fontKey;
    final size = _draft.sizeFrac ?? t.sizeFrac;
    final color = _draft.textColor ?? t.textColor;
    final align = _draft.align ?? t.align;
    final bold = _draft.bold ?? t.bold;
    final shadow = _draft.shadow ?? t.shadow;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Text status'),
        actions: [
          IconButton(
            tooltip: 'Reset style',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => _update(_draft.copyWith(clearOverrides: true)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Semantics(
                    label: 'Status preview',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: CustomPaint(painter: _StatusPainter(_draft)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              children: [
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kStatusTemplates.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final tpl = kStatusTemplates[i];
                      final selected = tpl.id == _draft.templateId;
                      return Semantics(
                        label: '${tpl.name} template',
                        button: true,
                        selected: selected,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () => _pickTemplate(tpl),
                          child: Container(
                            width: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 3),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: CustomPaint(
                                painter: _StatusPainter(StatusDraft(templateId: tpl.id, text: 'Aa अ')),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<StatusLanguage>(
                  showSelectedIcon: false,
                  segments: [for (final l in StatusLanguage.values) ButtonSegment(value: l, label: Text(l.label))],
                  selected: {_lang},
                  onSelectionChanged: (s) => _pickLanguage(s.first),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _text,
                  maxLength: kMaxStatusChars,
                  minLines: 2,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Your message', hintText: 'Type in English or हिन्दी'),
                  onChanged: (v) => _update(_draft.copyWith(text: v)),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in kEditorFonts)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(f.label,
                                style: TextStyle(fontFamily: f.family, fontFamilyFallback: const [kDevanagariFallbackFamily])),
                            selected: fontKey == f.key,
                            onSelected: (_) => _update(_draft.copyWith(fontKey: f.key)),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(width: 48, child: Text('Size')),
                    Expanded(
                      child: Slider(
                        value: size.clamp(0.04, 0.16),
                        min: 0.04,
                        max: 0.16,
                        onChanged: (v) => _update(_draft.copyWith(sizeFrac: v)),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final c in kSwatches)
                        Padding(
                          padding: const EdgeInsets.all(5),
                          child: Semantics(
                            label: 'Text colour ${c.toRadixString(16).toUpperCase()}',
                            button: true,
                            selected: c == color,
                            child: InkResponse(
                              onTap: () => _update(_draft.copyWith(textColor: c)),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c == color ? scheme.primary : scheme.outlineVariant,
                                    width: c == color ? 3 : 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    SegmentedButton<OverlayAlign>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: OverlayAlign.left, icon: Icon(Icons.format_align_left), tooltip: 'Align left'),
                        ButtonSegment(value: OverlayAlign.center, icon: Icon(Icons.format_align_center), tooltip: 'Align centre'),
                        ButtonSegment(value: OverlayAlign.right, icon: Icon(Icons.format_align_right), tooltip: 'Align right'),
                      ],
                      selected: {align},
                      onSelectionChanged: (s) => _update(_draft.copyWith(align: s.first)),
                    ),
                    FilterChip(label: const Text('Bold'), selected: bold, onSelected: (v) => _update(_draft.copyWith(bold: v))),
                    FilterChip(label: const Text('Shadow'), selected: shadow, onSelected: (v) => _update(_draft.copyWith(shadow: v))),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Save'),
                        onPressed: _saving ? null : () => _save(share: false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.ios_share),
                        label: const Text('Save & share'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                        onPressed: _saving ? null : () => _save(share: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Exports a 1080 × 1920 image. Share it to WhatsApp from the share sheet and post it as your status.',
                  style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPainter extends CustomPainter {
  _StatusPainter(this.draft);
  final StatusDraft draft;

  @override
  void paint(Canvas canvas, Size size) => paintStatus(canvas, size, draft);

  @override
  bool shouldRepaint(_StatusPainter old) => old.draft != draft;
}
