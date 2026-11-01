// lib/features/status/presentation/widgets/missing_status_help.dart
//
// Small, non-blocking help for "a status is in WhatsApp but not in WazApp". It is about MEDIA
// AVAILABILITY only; folder-permission problems are shown separately (see SourceAccessProblem).
//
// What was verified (docs/audit/RELEASE_EVIDENCE.md, Phase 7): the status folder holds only files
// WhatsApp itself has already written; WazApp never sees a status that is not in that folder, and
// nothing else (no database, no thumbnail list) tells it one exists. So the wording says "may",
// never promises that viewing a status makes it appear, and WazApp never opens or views a status
// on the user's behalf.

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/waz_theme.dart';
import '../../../../core/widgets/design_components.dart';
import '../../domain/status_models.dart';

class MissingStatusHelp extends StatefulWidget {
  const MissingStatusHelp({super.key, required this.app, required this.onCheckAgain, required this.onOpenApp});

  final StatusApp app;
  final VoidCallback onCheckAgain;
  final VoidCallback onOpenApp;

  @override
  State<MissingStatusHelp> createState() => _MissingStatusHelpState();
}

class _MissingStatusHelpState extends State<MissingStatusHelp> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = widget.app.label;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.xl - 2),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
              child: Row(
                children: [
                  Icon(Icons.help_outline, size: 20, color: scheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Missing a status?', style: AppTextStyles.titleSmall)),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.base,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WazApp can only list media that $label has already saved to its status folder. Some statuses '
                          'may appear here only after $label has downloaded them, for example once you have opened '
                          'them in $label. This is not guaranteed, and WazApp never opens or views statuses for you.',
                          style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Open $label, view the status, come back and check again. Statuses also disappear from '
                          '$label after 24 hours.',
                          style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            FilledButton.icon(
                              onPressed: widget.onCheckAgain,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Check again'),
                            ),
                            OutlinedButton.icon(
                              onPressed: widget.onOpenApp,
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: Text('Open $label'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
