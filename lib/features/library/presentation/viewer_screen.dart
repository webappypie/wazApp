// lib/features/library/presentation/viewer_screen.dart
//
// Full-screen viewer for saved items: swipe between items, pinch-zoom photos,
// video controls only for videos, favourite/share/export/delete/info actions.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/format.dart';
import '../domain/library_models.dart';
import 'library_actions.dart';
import 'library_providers.dart';
import 'saved_screen.dart';

class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({super.key, required this.args});
  final ViewerArgs args;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  late final PageController _pages = PageController(initialPage: widget.args.index);
  late int _index = widget.args.index;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<SavedMedia> _resolve() {
    final byId = {for (final m in ref.watch(libraryItemsProvider).value ?? const <SavedMedia>[]) m.id: m};
    return [for (final id in widget.args.ids) if (byId[id] != null) byId[id]!];
  }

  @override
  Widget build(BuildContext context) {
    final items = _resolve();
    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This item is no longer in your library.')),
      );
    }
    final index = _index.clamp(0, items.length - 1);
    final current = items[index];
    final canExport = ref.watch(statusAccessServiceProvider).isSupported;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: Text('${index + 1} / ${items.length}', style: AppTextStyles.titleSmall),
        actions: [
          IconButton(
            tooltip: current.isFavourite ? 'Remove from favourites' : 'Add to favourites',
            icon: Icon(current.isFavourite ? Icons.favorite : Icons.favorite_border),
            onPressed: () => ref.read(libraryServiceProvider).setFavourite([current.id], !current.isFavourite),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => shareMedia(context, [current]),
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (v) async {
              switch (v) {
                case 'gallery':
                  await exportFlow(context, ref, [current]);
                case 'info':
                  _showInfo(current);
                case 'delete':
                  final r = await deleteFlow(context, ref, [current.id]);
                  if (r != null && r.deleted > 0 && context.mounted) {
                    if (items.length <= 1) {
                      context.pop();
                    } else {
                      setState(() {});
                    }
                  }
              }
            },
            itemBuilder: (_) => [
              if (canExport) const PopupMenuItem(value: 'gallery', child: Text('Save to gallery')),
              const PopupMenuItem(value: 'info', child: Text('Details')),
              const PopupMenuItem(value: 'delete', child: Text('Delete…')),
            ],
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final m = items[i];
          return m.isVideo
              ? _VideoPage(key: ValueKey(m.id), media: m, active: i == index)
              : _ImagePage(key: ValueKey(m.id), media: m);
        },
      ),
    );
  }

  void _showInfo(SavedMedia m) {
    final rows = <(String, String)>[
      ('Type', m.isVideo ? 'Video' : 'Photo'),
      ('Size', formatBytes(m.sizeBytes)),
      if (m.width > 0) ('Dimensions', '${m.width} × ${m.height}'),
      if (m.isVideo) ('Duration', formatDuration(m.duration)),
      ('Saved', formatRelativeDate(m.savedAt)),
      ('Source', switch (m.sourceType) {
        'status' => m.sourceApp == 'business' ? 'WhatsApp Business status' : 'WhatsApp status',
        'imported' => 'Imported',
        'edited' => 'Edited',
        _ => 'Created in WazApp',
      }),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Details', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              for (final (k, v) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(width: 110, child: Text(k, style: AppTextStyles.bodyMedium)),
                    Expanded(child: Text(v, style: AppTextStyles.bodyMedium)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingFile extends ConsumerWidget {
  const _MissingFile({required this.media});
  final SavedMedia media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 56),
          const SizedBox(height: AppSpacing.sm),
          const Text('This file is missing or damaged.', style: TextStyle(color: Colors.white)),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () => ref.read(libraryServiceProvider).delete([media.id]),
            child: const Text('Remove from library'),
          ),
        ],
      ),
    );
  }
}

class _ImagePage extends StatelessWidget {
  const _ImagePage({super.key, required this.media});
  final SavedMedia media;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context);
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.file(
          File(media.path),
          fit: BoxFit.contain,
          cacheWidth: width.clamp(300, 2048).toInt(),
          semanticLabel: media.fileName,
          errorBuilder: (_, _, _) => _MissingFile(media: media),
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({super.key, required this.media, required this.active});
  final SavedMedia media;
  final bool active;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final file = File(widget.media.path);
    if (!await file.exists()) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final c = VideoPlayerController.file(file);
    try {
      await c.initialize();
      await c.setLooping(true);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _c = c);
      if (widget.active) await c.play();
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(_VideoPage old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      widget.active ? _c?.play() : _c?.pause();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return Consumer(builder: (_, ref, _) => _MissingFile(media: widget.media));
    final c = _c;
    if (c == null) return const Center(child: CircularProgressIndicator());
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
        _Controls(controller: c),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, v, _) {
        final total = v.duration.inMilliseconds.clamp(1, 1 << 31).toDouble();
        final pos = v.position.inMilliseconds.clamp(0, total.toInt()).toDouble();
        return Stack(
          children: [
            Center(
              child: IconButton.filled(
                iconSize: 40,
                tooltip: v.isPlaying ? 'Pause' : 'Play',
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () => v.isPlaying ? controller.pause() : controller.play(),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(children: [
                    Text(formatDuration(v.position), style: const TextStyle(color: Colors.white)),
                    Expanded(
                      child: Slider(
                        value: pos,
                        max: total,
                        onChanged: (x) => controller.seekTo(Duration(milliseconds: x.round())),
                      ),
                    ),
                    Text(formatDuration(v.duration), style: const TextStyle(color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
