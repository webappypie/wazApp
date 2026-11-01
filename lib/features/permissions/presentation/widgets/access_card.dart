// lib/features/permissions/presentation/widgets/access_card.dart
//
// One permission/access item with its REAL state, what it is needed for, and the action that
// fits that state. Shared by the first-launch setup and Settings > Permissions & Access.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/access_models.dart';
import '../access_controller.dart';

class _Copy {
  const _Copy(this.title, this.icon, this.neededFor);
  final String title;
  final IconData icon;
  final String neededFor;
}

const _copy = {
  AccessItem.whatsapp: _Copy(
    'WhatsApp',
    Icons.chat_bubble_outline,
    'Needed to browse and save the statuses you have viewed in WhatsApp. You pick its status folder once; WazApp only reads it.',
  ),
  AccessItem.whatsappBusiness: _Copy(
    'WhatsApp Business',
    Icons.storefront_outlined,
    'Needed to browse and save statuses from WhatsApp Business. It has its own folder, so it is set up separately.',
  ),
  AccessItem.media: _Copy(
    'Photos & files',
    Icons.photo_library_outlined,
    'Used to import media, edit it and save copies to your gallery. WazApp uses the system picker, so it never needs blanket storage access.',
  ),
  AccessItem.notifications: _Copy(
    'Notifications',
    Icons.notifications_none,
    'Optional. Lets WazApp show service notices and updates. Everything else works without it.',
  ),
  AccessItem.locker: _Copy(
    'Private Folder lock',
    Icons.lock_outline,
    'Optional. Asks for your fingerprint, face or screen lock before the Private Folder opens.',
  ),
};

String accessTitle(AccessItem item) => _copy[item]!.title;

/// Short, honest label for the status chip.
String accessStatusLabel(AccessItem item, AccessStatus s) => switch (s) {
  AccessStatus.granted => item == AccessItem.locker ? 'On' : 'Allowed',
  AccessStatus.notRequested => switch (item) {
    AccessItem.locker => 'Off',
    AccessItem.notifications => 'Not asked yet',
    _ => 'Not set up',
  },
  AccessStatus.denied => 'Denied',
  AccessStatus.permanentlyDenied => 'Blocked',
  AccessStatus.notInstalled => 'Not installed',
  AccessStatus.revoked => 'Access lost',
  AccessStatus.folderMissing => 'Folder not found',
  AccessStatus.notNeeded => 'No permission needed',
  AccessStatus.needsSystemSetup => 'Needs screen lock',
  AccessStatus.unsupported => 'Unavailable',
};

String accessDetail(AccessItem item, AccessStatus s) {
  final label = _copy[item]!.title;
  switch (s) {
    case AccessStatus.granted:
      return switch (item) {
        AccessItem.whatsapp || AccessItem.whatsappBusiness =>
          'Connected. $label statuses can be browsed and saved.',
        AccessItem.notifications => 'Notifications are allowed.',
        AccessItem.locker =>
          'The Private Folder asks for authentication each time you open it.',
        AccessItem.media => '',
      };
    case AccessStatus.notRequested:
      return switch (item) {
        AccessItem.locker =>
          'Not turned on. The Private Folder opens without asking.',
        AccessItem.notifications => 'You have not been asked yet.',
        _ => 'Not set up yet. Choose the $label status folder to connect it.',
      };
    case AccessStatus.denied:
      return 'You said no. You can try once more, or leave it off.';
    case AccessStatus.permanentlyDenied:
      return item == AccessItem.notifications
          ? 'Notifications are off in system settings. Turn them on there if you want them.'
          : 'Blocked in system settings.';
    case AccessStatus.notInstalled:
      return '$label is not installed on this device.';
    case AccessStatus.revoked:
      return 'WazApp lost access to the $label status folder. Choose the folder again.';
    case AccessStatus.folderMissing:
      return 'The $label status folder cannot be found. Open $label and view a status, then check again.';
    case AccessStatus.notNeeded:
      return 'Nothing to grant on this device.';
    case AccessStatus.needsSystemSetup:
      return 'This phone has no screen lock set up. Add a PIN, pattern, password or biometrics in system settings first.';
    case AccessStatus.unsupported:
      return 'This device cannot provide it.';
  }
}

Color _statusColor(ColorScheme scheme, AccessStatus s) => switch (s) {
  AccessStatus.granted || AccessStatus.notNeeded => kColorSuccess,
  AccessStatus.notInstalled || AccessStatus.unsupported => scheme.outline,
  AccessStatus.notRequested => scheme.primary,
  _ => kColorWarning,
};

IconData _statusIcon(AccessStatus s) => switch (s) {
  AccessStatus.granted || AccessStatus.notNeeded => Icons.check_circle,
  AccessStatus.notInstalled ||
  AccessStatus.unsupported => Icons.remove_circle_outline,
  AccessStatus.notRequested => Icons.radio_button_unchecked,
  _ => Icons.error_outline,
};

/// Runs [item]'s action and reports the real outcome in a snackbar.
Future<void> runAccessAction(
  BuildContext context,
  WidgetRef ref,
  AccessItem item,
) async {
  final outcome = await ref.read(accessOverviewProvider.notifier).act(item);
  if (!context.mounted) return;
  final title = accessTitle(item);
  final msg = switch (outcome) {
    AccessActionOutcome.granted => switch (item) {
      AccessItem.locker => 'Private Folder lock is on',
      AccessItem.notifications => 'Notifications allowed',
      _ => '$title connected',
    },
    AccessActionOutcome.cancelled => switch (item) {
      AccessItem.notifications => 'Notifications were not allowed',
      _ => 'No folder was chosen',
    },
    AccessActionOutcome.wrongFolder =>
      'That folder does not contain $title statuses. Open the $title folder and choose it again.',
    AccessActionOutcome.openedSettings => 'Change it in system settings, then come back. WazApp re-checks automatically.',
    AccessActionOutcome.settingsUnavailable =>
      'Could not open system settings on this device.',
    AccessActionOutcome.notConfirmed =>
      'Not changed. Authentication was not completed.',
    AccessActionOutcome.needsLockSetup =>
      'Set up a screen lock in your phone settings first.',
    AccessActionOutcome.failed => 'Something went wrong. Please try again.',
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

class AccessCard extends ConsumerStatefulWidget {
  const AccessCard({super.key, required this.snapshot, this.compact = false});

  final AccessSnapshot snapshot;

  /// Settings uses the compact form (no long "needed for" text under granted items).
  final bool compact;

  @override
  ConsumerState<AccessCard> createState() => _AccessCardState();
}

class _AccessCardState extends ConsumerState<AccessCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.snapshot.item;
    final status = widget.snapshot.status;
    final scheme = Theme.of(context).colorScheme;
    final copy = _copy[item]!;
    final color = _statusColor(scheme, status);
    final controller = ref.read(accessOverviewProvider.notifier);
    final label = accessStatusLabel(item, status);

    final actions = <Widget>[];
    void primary(String text, VoidCallback onTap, {IconData? icon}) =>
        actions.add(
          FilledButton.icon(
            onPressed: _busy ? null : onTap,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon ?? Icons.check, size: 18),
            label: Text(text),
          ),
        );
    void secondary(String text, VoidCallback onTap, {IconData? icon}) =>
        actions.add(
          OutlinedButton.icon(
            onPressed: _busy ? null : onTap,
            icon: Icon(icon ?? Icons.refresh, size: 18),
            label: Text(text),
          ),
        );

    final isFolder = item.statusApp != null;
    switch (status) {
      case AccessStatus.notRequested:
        primary(
          isFolder
              ? 'Choose folder'
              : item == AccessItem.locker
              ? 'Turn on'
              : 'Allow',
          () => _run(() => runAccessAction(context, ref, item)),
          icon: isFolder ? Icons.folder_open : Icons.check,
        );
      case AccessStatus.denied:
        primary(
          'Try again',
          () => _run(() => runAccessAction(context, ref, item)),
          icon: Icons.refresh,
        );
      case AccessStatus.permanentlyDenied:
        primary(
          'Open settings',
          () => _run(() async {
            await controller.openSystemSettings(item);
          }),
          icon: Icons.settings_outlined,
        );
      case AccessStatus.revoked:
      case AccessStatus.folderMissing:
        primary(
          'Choose folder again',
          () => _run(() => runAccessAction(context, ref, item)),
          icon: Icons.folder_open,
        );
        secondary('Check again', () => _run(controller.refresh));
      case AccessStatus.needsSystemSetup:
        primary(
          'Open security settings',
          () => _run(() => runAccessAction(context, ref, item)),
          icon: Icons.settings_outlined,
        );
        secondary('Check again', () => _run(controller.refresh));
      case AccessStatus.granted:
        if (isFolder) {
          secondary(
            'Change folder',
            () => _run(() => runAccessAction(context, ref, item)),
            icon: Icons.folder_open,
          );
          secondary(
            'Remove access',
            () => _run(() => controller.removeFolder(item.statusApp!)),
            icon: Icons.link_off,
          );
        } else if (item == AccessItem.locker) {
          secondary(
            'Turn off',
            () => _run(() async {
              final r = await controller.disableLocker();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      r == AccessActionOutcome.granted
                          ? 'Private Folder lock is off'
                          : 'Not changed. Authentication was not completed.',
                    ),
                  ),
                );
            }),
            icon: Icons.lock_open,
          );
        } else if (item == AccessItem.notifications) {
          secondary(
            'Notification settings',
            () => _run(() async {
              await controller.openSystemSettings(item);
            }),
            icon: Icons.settings_outlined,
          );
        }
      case AccessStatus.notInstalled:
      case AccessStatus.notNeeded:
      case AccessStatus.unsupported:
        break;
    }

    final detail = accessDetail(item, status);
    final dim =
        status == AccessStatus.notInstalled ||
        status == AccessStatus.unsupported;

    return Semantics(
      container: true,
      label: '${copy.title}: $label',
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circular "status ring" avatar: ring colour follows the real state.
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 3),
                    ),
                    child: Icon(
                      copy.icon,
                      color: dim ? scheme.outline : scheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(copy.title, style: AppTextStyles.titleMedium),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(_statusIcon(status), size: 16, color: color),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                label,
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (!(widget.compact && status.isGranted))
                Text(
                  copy.neededFor,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(detail, style: AppTextStyles.bodyMedium),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
