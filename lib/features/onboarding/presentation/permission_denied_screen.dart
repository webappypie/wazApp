// lib/features/onboarding/presentation/permission_denied_screen.dart
//
// Shown when the user denies or permanently denies permissions.
// Must not be a dead end — always provides a clear path forward.
//
// Two modes:
//   - denied (can still ask again): shows "Try again" → permission_request
//   - permanentlyDenied: shows "Open Settings" → system app settings
//
// The UI never lies about what state we're in. "Open Settings" is only shown
// when we know it's the only way to proceed (REQ-ONB-04 implicit).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/media_access/media_access_service.dart';
import '../../../core/widgets/buttons.dart';

class PermissionDeniedScreen extends ConsumerStatefulWidget {
  const PermissionDeniedScreen({super.key});

  @override
  ConsumerState<PermissionDeniedScreen> createState() => _PermissionDeniedScreenState();
}

class _PermissionDeniedScreenState extends ConsumerState<PermissionDeniedScreen>
    with WidgetsBindingObserver {
  MediaPermissionState? _state;
  bool _waitingForSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_waitingForSettings && state == AppLifecycleState.resumed) {
      _waitingForSettings = false;
      _checkState();
    }
  }

  Future<void> _checkState() async {
    final svc = ref.read(mediaAccessServiceProvider);
    final state = await svc.checkPermission();
    if (!mounted) return;
    if (state == MediaPermissionState.granted || state == MediaPermissionState.limited) {
      // User granted from Settings — proceed.
      await ref.read(onboardingServiceProvider).markOnboardingComplete();
      if (mounted) context.go(AppRoutes.home);
      return;
    }
    setState(() => _state = state);
  }

  void _tryAgain() => context.go(AppRoutes.permissionRequest);

  Future<void> _openSettings() async {
    _waitingForSettings = true;
    await ref.read(mediaAccessServiceProvider).openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPermanent = _state == MediaPermissionState.permanentlyDenied;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Icon(
                Icons.image_not_supported_outlined,
                size: 56,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                isPermanent ? 'Permission required' : 'Access declined',
                style: AppTextStyles.headlineSmall.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isPermanent
                    ? 'You\'ve declined access more than once. To use WappTidy, '
                      'open Settings and allow media access for this app.'
                    : 'Without media access, WappTidy can\'t scan your WhatsApp files. '
                      'Tap "Try again" to see the permission request.',
                style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              if (isPermanent)
                PrimaryButton(
                  label: 'Open Settings',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                )
              else
                PrimaryButton(
                  label: 'Try again',
                  onPressed: _tryAgain,
                ),
              const SizedBox(height: AppSpacing.sm),
              // Limited-use only: allow continuing without media access
              // (app will be in a degraded state with empty screens)
              Center(
                child: TextButton(
                  onPressed: () async {
                    await ref.read(onboardingServiceProvider).markOnboardingComplete();
                    if (context.mounted) context.go(AppRoutes.home);
                  },
                  child: Text(
                    'Continue without access',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
