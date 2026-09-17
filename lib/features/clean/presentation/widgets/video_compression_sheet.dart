// lib/features/clean/presentation/widgets/video_compression_sheet.dart
//
// Modal sheet for Video Compression workflow (REQ-ACT-09, REQ-CMP-01..04).
//
// RULES:
//   - REQ-ACT-09: Original is NEVER removed until output is verified AND user confirmed replacement.
//   - REQ-CMP-02: Savings are clearly marked "Estimated" prior to compression.
//   - REQ-CMP-04: Live progress bar and cancellable button.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/category_models.dart';
import '../../domain/compression_models.dart';
import '../../services/video_compression_service.dart';

class VideoCompressionSheet extends ConsumerStatefulWidget {
  const VideoCompressionSheet({
    super.key,
    required this.item,
    this.customService,
  });

  final CategoryItem item;
  final VideoCompressionService? customService;

  static Future<bool?> show(
    BuildContext context, {
    required CategoryItem item,
    VideoCompressionService? customService,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VideoCompressionSheet(
        item: item,
        customService: customService,
      ),
    );
  }

  @override
  ConsumerState<VideoCompressionSheet> createState() =>
      _VideoCompressionSheetState();
}

class _VideoCompressionSheetState extends ConsumerState<VideoCompressionSheet> {
  VideoQualityProfile _selectedProfile = VideoQualityProfile.balanced;
  CompressionProgress _progress = CompressionProgress.idle;
  CompressionResult? _result;
  bool _isFinalizing = false;

  VideoCompressionService get _service =>
      widget.customService ?? ref.read(videoCompressionServiceProvider);

  Future<void> _startCompression() async {
    setState(() {
      _progress = const CompressionProgress(
        step: CompressionStep.preparing,
        progressFraction: 0.0,
      );
      _result = null;
    });

    try {
      final res = await _service.compressVideo(
        item: widget.item,
        profile: _selectedProfile,
        onProgress: (prog) {
          if (mounted) {
            setState(() => _progress = prog);
          }
        },
      );

      if (mounted) {
        setState(() {
          _result = res;
          _progress = const CompressionProgress(
            step: CompressionStep.completed,
            progressFraction: 1.0,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = CompressionProgress(
            step: CompressionStep.error,
            progressFraction: 0.0,
            errorMessage: e.toString(),
          );
        });
      }
    }
  }

  Future<void> _cancelCompression() async {
    await _service.cancelCompression();
    if (mounted) {
      setState(() {
        _progress = const CompressionProgress(
          step: CompressionStep.cancelled,
          progressFraction: 0.0,
        );
      });
    }
  }

  Future<void> _finalize(bool replaceOriginal) async {
    if (_result == null) return;
    setState(() => _isFinalizing = true);

    try {
      final success = await _service.finalizeReplacement(
        result: _result!,
        replaceOriginal: replaceOriginal,
      );
      if (mounted) {
        Navigator.of(context).pop(success);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isFinalizing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estimate = _service.estimateSavings(
      item: widget.item,
      profile: _selectedProfile,
    );

    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header title
              Row(
                children: [
                  Icon(Icons.video_settings_rounded, color: scheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Compress Video',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.item.displayName,
                style: AppTextStyles.bodySmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),

              // Main body depending on state
              if (_progress.step.isActive)
                _buildProgressView(scheme)
              else if (_result != null)
                _buildResultView(scheme, _result!)
              else
                _buildConfigurationView(scheme, estimate),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationView(
    ColorScheme scheme,
    CompressionEstimate estimate,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quality profile selection
        Text(
          'Target Quality Profile',
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...VideoQualityProfile.values.map(
          (p) {
            final isSelected = p == _selectedProfile;
            return InkWell(
              onTap: () => setState(() => _selectedProfile = p),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xs,
                  horizontal: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.displayName, style: AppTextStyles.bodyMedium),
                          Text(p.description, style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.sm),

        // REQ-CMP-02: Clear Estimated Savings banner
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: scheme.primaryContainer),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated Savings: ${estimate.formattedEstimatedSavings} (~${estimate.estimatedSavingsPercentage}%)',
                style: AppTextStyles.titleSmall.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Original: ${estimate.formattedOriginalSize}  ➜  Estimated Output: ${estimate.formattedEstimatedSize}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Start button
        ElevatedButton.icon(
          onPressed: _startCompression,
          icon: const Icon(Icons.compress_rounded),
          label: const Text('Start Compression'),
        ),
      ],
    );
  }

  Widget _buildProgressView(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'Compressing video...',
          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(
          value: _progress.progressFraction,
          borderRadius: BorderRadius.circular(4),
          minHeight: 8,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_progress.progressPercentage}%',
          style: AppTextStyles.labelMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: _cancelCompression,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel Transcode'),
        ),
      ],
    );
  }

  Widget _buildResultView(ColorScheme scheme, CompressionResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle_rounded, color: scheme.primary, size: 48),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Compression Verified!',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Actual Savings: ${result.formattedActualSavings} (${result.actualSavingsPercentage}%)',
          style: AppTextStyles.bodyMedium.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          'Original: ${result.formattedOriginalSize}  ➜  New: ${result.formattedCompressedSize}',
          style: AppTextStyles.bodySmall.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),

        // REQ-ACT-09: User decision options
        ElevatedButton(
          onPressed: _isFinalizing ? null : () => _finalize(true),
          child: _isFinalizing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Replace Original (Move to Bin)'),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: _isFinalizing ? null : () => _finalize(false),
          child: const Text('Keep Both Files'),
        ),
      ],
    );
  }
}
