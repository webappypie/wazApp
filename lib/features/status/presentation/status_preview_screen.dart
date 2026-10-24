// lib/features/status/presentation/status_preview_screen.dart
//
// Preview of a status that has not been saved yet, with a Save action.
// Images use a larger native thumbnail; videos stream the SAF document.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/library_actions.dart';
import '../domain/status_models.dart';
import 'status_providers.dart';

class StatusPreviewScreen extends ConsumerStatefulWidget {
  const StatusPreviewScreen({super.key, required this.item});
  final StatusItem item;

  @override
  ConsumerState<StatusPreviewScreen> createState() => _StatusPreviewScreenState();
}

class _StatusPreviewScreenState extends ConsumerState<StatusPreviewScreen> {
  VideoPlayerController? _video;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.kind == MediaKind.video) _initVideo();
  }

  Future<void> _initVideo() async {
    final c = VideoPlayerController.contentUri(Uri.parse(widget.item.uri));
    try {
      await c.initialize();
      await c.setLooping(true);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _video = c);
      await c.play();
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _videoFailed = true);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedSourceKeysProvider).value?.contains(widget.item.sourceKey) ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.item.app.label),
      ),
      body: _content(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: Icon(saved ? Icons.check : Icons.download_rounded),
            label: Text(saved ? 'Already saved' : 'Save'),
            onPressed: saved
                ? null
                : () => saveStatusesFlow(context, ref, [widget.item],
                    onViewSaved: () => context.go(AppRoutes.saved)),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (widget.item.kind == MediaKind.video) {
      if (_videoFailed) return const Center(child: Text('This video cannot be played.', style: TextStyle(color: Colors.white)));
      final c = _video;
      if (c == null) return const Center(child: CircularProgressIndicator());
      return Center(
        child: GestureDetector(
          onTap: () => c.value.isPlaying ? c.pause() : c.play(),
          child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
        ),
      );
    }
    return Consumer(builder: (context, ref, _) {
      final bytes = ref.watch(_largeImageProvider(widget.item));
      return bytes.when(
        data: (b) => b == null
            ? const Center(child: Text('This image cannot be shown.', style: TextStyle(color: Colors.white)))
            : InteractiveViewer(child: Center(child: Image.memory(b, fit: BoxFit.contain))),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('This image cannot be shown.', style: TextStyle(color: Colors.white))),
      );
    });
  }
}

final _largeImageProvider = FutureProvider.autoDispose.family((ref, StatusItem item) {
  return ref.watch(mediaToolsProvider).thumbnail(item.uri, item.kind, size: 1600);
});
