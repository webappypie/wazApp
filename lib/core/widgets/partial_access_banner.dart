// lib/core/widgets/partial_access_banner.dart
//
// REQ-ONB-05: Partial access banner — shown on every media screen when the
// user granted only selected-photos access (Android 14+).
//
// This must be persistent — shown every time the screen is displayed,
// not just once at grant time. Screens include it in their build() near the top.
//
// Visibility is driven by the mediaPermissionStateProvider. When the user
// upgrades to full access, the banner disappears immediately.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../di/providers.dart';
import '../services/media_access/media_access_service.dart';

/// Riverpod provider that exposes the current media permission state.
/// Updated on every app resume (handled in RealMediaAccessService, Phase 3).
final mediaPermissionStateProvider = FutureProvider<MediaPermissionState>((ref) async {
  final svc = ref.watch(mediaAccessServiceProvider);
  return svc.checkPermission();
});

/// Banner that appears at the top of any media-displaying screen when the
/// user has granted only partial (selected-photos) access.
///
/// Wrap inside a [Column] at the top of the screen body:
/// ```dart
/// Column(children: [
///   const PartialAccessBanner(),
///   Expanded(child: ... media content ...),
/// ])
/// ```
class PartialAccessBanner extends ConsumerWidget {
  const PartialAccessBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permState = ref.watch(mediaPermissionStateProvider);

    return permState.when(
      data: (state) {
        if (state == MediaPermissionState.granted) return const SizedBox.shrink();
        if (state == MediaPermissionState.limited) return _BannerContent();
        return _DeniedBannerContent(isPermanent: state == MediaPermissionState.permanentlyDenied || state == MediaPermissionState.restricted);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _BannerContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      color: kColorWarning.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.sm,
      ),
      child: Semantics(
        liveRegion: true,
        label: 'Partial media access. Only selected photos are visible. '
            'Tap to grant full access.',
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: kColorWarning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Only selected photos are visible. '
                'Some duplicates or large files may be hidden.',
                style: AppTextStyles.bodySmall.copyWith(color: kColorWarning),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: () async {
                await ref.read(mediaAccessServiceProvider).openAppSettings();
              },
              child: Text(
                'Fix',
                style: AppTextStyles.labelSmall.copyWith(
                  color: kColorWarning,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeniedBannerContent extends ConsumerWidget {
  const _DeniedBannerContent({required this.isPermanent});
  final bool isPermanent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.sm,
      ),
      child: Semantics(
        liveRegion: true,
        label: 'Media permissions required to scan WhatsApp files. Tap to grant access.',
        child: Row(
          children: [
            Icon(Icons.folder_off_outlined, size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Media access is required to find WhatsApp media.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: () async {
                final svc = ref.read(mediaAccessServiceProvider);
                if (isPermanent) {
                  await svc.openAppSettings();
                } else {
                  await svc.requestPermission();
                }
                ref.invalidate(mediaPermissionStateProvider);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.error,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPermanent ? 'Settings' : 'Grant',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: scheme.onError,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
