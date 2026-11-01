// lib/features/permissions/presentation/permission_setup_screen.dart
//
// Guided first-launch setup. Shows the real state of every item WazApp can use, explains what each
// one is for, and lets the user grant, retry or skip. Nothing is requested automatically: every
// system prompt or picker appears only after the user taps its button.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/state_widgets.dart';
import '../domain/access_models.dart';
import 'access_controller.dart';
import 'widgets/access_card.dart';

class PermissionSetupScreen extends ConsumerStatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  ConsumerState<PermissionSetupScreen> createState() =>
      _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends ConsumerState<PermissionSetupScreen> {
  bool _finishing = false;

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await ref.read(onboardingServiceProvider).markOnboardingComplete();
    } catch (_) {
      // If the flag cannot be stored the setup simply shows again next launch.
    }
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(accessOverviewProvider);
    final scheme = Theme.of(context).colorScheme;
    final supported = ref.watch(statusAccessServiceProvider).isSupported;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Set up WazApp'),
        actions: [
          IconButton(
            tooltip: 'Check again',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(accessOverviewProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: overview.when(
                loading: () => const SkeletonListLoader(),
                error: (e, _) => ErrorState(
                  message: 'Could not read permission states.',
                  onRetry: () => ref.invalidate(accessOverviewProvider),
                ),
                data: (data) {
                  final items = data.visible;
                  // Setup order: sources first, then optional extras.
                  const order = [
                    AccessItem.whatsapp,
                    AccessItem.whatsappBusiness,
                    AccessItem.notifications,
                    AccessItem.locker,
                    AccessItem.media,
                  ];
                  items.sort(
                    (a, b) =>
                        order.indexOf(a.item).compareTo(order.indexOf(b.item)),
                  );
                  return ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          supported
                              ? 'Connect each WhatsApp app separately, then choose the optional extras. '
                                    'Nothing happens until you tap a button, and you can change everything later in '
                                    'Settings › Permissions & Access.'
                              : 'WazApp cannot look inside WhatsApp on this device. You can import photos and videos '
                                    'from Photos or Files, then edit and share them. Choose the optional extras below.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      for (final s in items) AccessCard(snapshot: s),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _finishing ? null : _finish,
                      child: const Text('Continue'),
                    ),
                  ),
                  TextButton(
                    onPressed: _finishing ? null : _finish,
                    child: const Text('Skip for now'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
