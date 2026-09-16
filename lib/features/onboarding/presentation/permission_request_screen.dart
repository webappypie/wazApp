// lib/features/onboarding/presentation/permission_request_screen.dart
//
// Triggers the actual Android system permission dialog.
// Handles all states returned by permission_handler:
//   - granted               → mark onboarding complete → home
//   - denied                → permission_denied screen
//   - permanentlyDenied     → permission_denied screen (with settings CTA)
//   - restricted            → permission_denied screen
//   - limited (Android 14+) → partial_access banner then home (REQ-ONB-05)
//
// Architecture: UI calls mediaAccessService.requestPermission() — the service
// abstraction wraps permission_handler. The real impl is in
// RealMediaAccessService (Phase 3). For Phase 2 we build the UI flow against
// FakeMediaAccessService.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/media_access/media_access_service.dart';

class PermissionRequestScreen extends ConsumerStatefulWidget {
  const PermissionRequestScreen({super.key});

  @override
  ConsumerState<PermissionRequestScreen> createState() => _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends ConsumerState<PermissionRequestScreen>
    with WidgetsBindingObserver {
  bool _isRequesting = false;
  bool _waitingForSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Trigger the dialog automatically on first entry.
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when the user returns from the system Settings app (deep link).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_waitingForSettings && state == AppLifecycleState.resumed) {
      _waitingForSettings = false;
      _requestPermission();
    }
  }

  Future<void> _requestPermission() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    final svc = ref.read(mediaAccessServiceProvider);
    // requestPermission() will trigger the system dialog on real devices.
    // On FakeMediaAccessService it returns whatever permissionState is set to.
    final state = await svc.requestPermission();

    if (!mounted) return;
    setState(() => _isRequesting = false);

    switch (state) {
      case MediaPermissionState.granted:
        // Full access — complete onboarding and go home.
        await ref.read(onboardingServiceProvider).markOnboardingComplete();
        if (mounted) context.go(AppRoutes.home);

      case MediaPermissionState.limited:
        // Android 14+ partial/selected access — show banner on all media screens.
        await ref.read(onboardingServiceProvider).markOnboardingComplete();
        if (mounted) context.go(AppRoutes.home);

      case MediaPermissionState.denied:
      case MediaPermissionState.permanentlyDenied:
      case MediaPermissionState.restricted:
        if (mounted) context.go(AppRoutes.permissionDenied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // This screen shows only while waiting for the system dialog to complete.
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: scheme.primary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Waiting for permission…',
                style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
