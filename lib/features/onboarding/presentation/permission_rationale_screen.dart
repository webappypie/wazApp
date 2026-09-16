// lib/features/onboarding/presentation/permission_rationale_screen.dart
//
// REQ-ONB-03: A real screen the user reads BEFORE the system dialog appears.
// Shows exactly what permissions are requested and why each is needed.
// No system dialog is triggered from this screen — the user must tap
// "Grant access" to proceed to the permission_request_screen where the
// actual platform dialog is shown.
//
// This is intentionally a separate screen from the system dialog so the user
// has time to read the rationale without a system overlay blocking the text.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/buttons.dart';

class PermissionRationaleScreen extends StatelessWidget {
  const PermissionRationaleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text(
                'One permission needed',
                style: AppTextStyles.headlineSmall.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'WappTidy needs access to your media so it can find duplicates, '
                'large files and old content saved from WhatsApp.',
                style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Permission cards
              _PermissionRow(
                icon: Icons.photo_library_outlined,
                title: 'Photos and videos',
                body: 'To scan and display your WhatsApp media. '
                    'Nothing is uploaded or shared.',
              ),
              const SizedBox(height: AppSpacing.md),
              _PermissionRow(
                icon: Icons.audio_file_outlined,
                title: 'Audio files',
                body: 'To find large voice notes and audio clips '
                    'from WhatsApp that may be taking up space.',
              ),
              const SizedBox(height: AppSpacing.md),

              // Privacy assurance
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: AppRadius.cardRadius,
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: scheme.primary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'All analysis happens on your device. '
                        'WappTidy never reads file contents, '
                        'contacts, or messages.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              PrimaryButton(
                label: 'Grant access',
                onPressed: () => context.go(AppRoutes.permissionRequest),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.permissionDenied),
                  child: Text(
                    'Not now',
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

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
          ),
          child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.titleSmall.copyWith(color: scheme.onSurface)),
              const SizedBox(height: AppSpacing.xs),
              Text(body, style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
