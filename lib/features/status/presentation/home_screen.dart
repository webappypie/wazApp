// lib/features/status/presentation/home_screen.dart
//
// Home: one hero card per INSTALLED WhatsApp app (WhatsApp, WhatsApp Business, or both), then
// create/import shortcuts. Detection (is the app installed?) and access (may WazApp read its status
// folder?) are separate states, each shown honestly:
//   only WhatsApp installed          -> one card
//   only WhatsApp Business installed -> one card
//   both installed                   -> two cards, kept apart
//   neither installed                -> an explanatory empty state, no placeholder cards
// iOS cannot read WhatsApp's storage, so it gets Photos/Files import only (never a fake feed).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/waz_theme.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/design_components.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../core/widgets/status_ring.dart';
import '../../../integrations/wapcentral/ads/ad_slot.dart';
import '../../../integrations/wapcentral/notifications/notifications_ui.dart';
import '../../../integrations/wapcentral/promo/promo_card.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/library_actions.dart';
import '../../permissions/domain/access_models.dart';
import '../../permissions/presentation/widgets/access_card.dart';
import '../domain/status_models.dart';
import 'source_screen.dart';
import 'status_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Apps get installed/removed and folder grants change while WazApp is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }

  void _recheck() {
    ref.invalidate(installedAppsProvider);
    for (final app in StatusApp.values) {
      ref.invalidate(statusAccessProvider(app));
      ref.invalidate(statusFolderStateProvider(app));
      ref.invalidate(statusListProvider(app));
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = ref.watch(statusAccessServiceProvider).isSupported;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => _recheck(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              _Header(onRefresh: supported ? _recheck : null),
              if (supported) ..._sources() else const Entrance(child: _ImportOnlyCard()),
              const SizedBox(height: AppSpacing.sm),
              const PromoCard(padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0)),
              const AdSlot(
                placementKey: AdPlacements.homeNative,
                padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
                child: SectionTitle('Create & import'),
              ),
              const _QuickActions(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sources() {
    final sources = ref.watch(availableSourcesProvider);
    return sources.when(
      loading: () => const [
        Padding(padding: EdgeInsets.all(AppSpacing.md), child: _CardSkeleton()),
      ],
      error: (_, _) => [
        SizedBox(
          height: 240,
          child: ErrorState(
            message: 'Could not check which WhatsApp apps are installed.',
            onRetry: () => ref.invalidate(installedAppsProvider),
          ),
        ),
      ],
      data: (apps) {
        if (apps.isEmpty) return const [Entrance(child: _NoWhatsAppCard())];
        return [
          for (var i = 0; i < apps.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
              child: Entrance(index: i, child: SourceCard(app: apps[i])),
            ),
        ];
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WazApp', style: AppTextStyles.headlineSmall),
                Text('Save. Style. Share.', style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          NotificationBellButton(onPressed: () => context.push(AppRoutes.notifications)),
          if (onRefresh != null) IconButton(tooltip: 'Check again', icon: const Icon(Icons.refresh), onPressed: onRefresh),
        ],
      ),
    );
  }
}

/// Hero card for one installed WhatsApp app: state, latest thumbnails and the one action that fits.
class SourceCard extends ConsumerWidget {
  const SourceCard({super.key, required this.app});
  final StatusApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waz = context.waz;
    final folder = ref.watch(statusFolderStateProvider(app));
    final state = folder.value;
    final granted = state == StatusFolderState.granted;
    final list = granted ? ref.watch(statusListProvider(app)) : null;
    final items = list?.value;
    final count = items?.length;
    final isBusiness = app == StatusApp.business;

    final (String subtitle, String pill, IconData pillIcon) = switch (state) {
      null => ('Checking...', 'Checking', Icons.sync),
      StatusFolderState.granted when list!.hasError => ('Could not read statuses', 'Retry', Icons.error_outline),
      StatusFolderState.granted when count == null => ('Loading statuses...', 'Loading', Icons.sync),
      StatusFolderState.granted when count == 0 => ('No statuses available yet', 'Connected', Icons.check_circle_outline),
      StatusFolderState.granted => (
        count == 1 ? '1 status available' : '$count statuses available',
        'Connected',
        Icons.check_circle_outline,
      ),
      StatusFolderState.notConfigured => ('Allow access to see its statuses', 'Not set up', Icons.lock_outline),
      StatusFolderState.revoked => ('Access to its folder was lost', 'Access lost', Icons.link_off),
      StatusFolderState.folderMissing => ('Its status folder was not found', 'Folder missing', Icons.folder_off_outlined),
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.xl,
      gradient: isBusiness ? waz.heroGradientAlt : waz.heroGradient,
      elevated: true,
      semanticLabel: '${app.label}, $subtitle',
      onTap: granted ? () => context.push('${AppRoutes.source}/${app.key}') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusRing(
                size: 64,
                strokeWidth: 4,
                segments: (count ?? 1).clamp(1, 12),
                color: granted ? waz.signature : waz.onHeroMuted,
                trackColor: Colors.white.withValues(alpha: 0.18),
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.14),
                  child: Icon(isBusiness ? Icons.storefront_outlined : Icons.chat_bubble_outline, color: waz.onHero),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.label, style: AppTextStyles.titleLarge.copyWith(color: waz.onHero)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodyMedium.copyWith(color: waz.onHeroMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusPill(label: pill, color: waz.signature, icon: pillIcon, onDark: true),
          ),
          if (granted && items != null && items.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _ThumbStrip(items: items),
          ],
          const SizedBox(height: AppSpacing.md),
          _action(context, ref, state, count),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, WidgetRef ref, StatusFolderState? state, int? count) {
    final waz = context.waz;
    final style = FilledButton.styleFrom(
      backgroundColor: waz.signature,
      foregroundColor: waz.onSignature,
      minimumSize: const Size(0, 48),
    );
    final item = AccessItem.forStatusApp(app);
    switch (state) {
      case StatusFolderState.granted:
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: style,
                onPressed: () => context.push('${AppRoutes.source}/${app.key}'),
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: Text(count == 0 ? 'Open and check again' : 'View statuses'),
              ),
            ),
          ],
        );
      case StatusFolderState.notConfigured:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Android keeps statuses in a private folder. Choose ${app.label}\'s status folder once; WazApp only '
              'reads it and never uploads anything.',
              style: AppTextStyles.bodySmall.copyWith(color: waz.onHeroMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              style: style,
              onPressed: () => runAccessAction(context, ref, item).then((_) => ref.invalidate(statusFolderStateProvider(app))),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Allow access'),
            ),
          ],
        );
      case StatusFolderState.revoked:
      case StatusFolderState.folderMissing:
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              style: style,
              onPressed: () => runAccessAction(context, ref, item).then((_) => ref.invalidate(statusFolderStateProvider(app))),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Choose folder again'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: waz.onHero),
              onPressed: () => ref.invalidate(statusFolderStateProvider(app)),
              child: const Text('Check again'),
            ),
          ],
        );
      case null:
        return const SizedBox(height: 48);
    }
  }
}

/// Latest status thumbnails (real files only).
class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({required this.items});
  final List<StatusItem> items;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(6).toList();
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final item = shown[i];
          return Semantics(
            label: '${item.kind.name} status',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: Colors.white.withValues(alpha: 0.12), child: StatusThumb(item: item)),
                    if (item.kind == MediaKind.video)
                      const Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.play_circle_fill, size: 20, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget tile(IconData icon, String title, String body, VoidCallback onTap, int index) => Expanded(
      child: Entrance(
        index: index + 2,
        child: AppCard(
          onTap: onTap,
          semanticLabel: '$title. $body',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccentIcon(icon: icon, color: scheme.primary),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: AppTextStyles.titleSmall),
              const SizedBox(height: 2),
              Text(body, style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tile(Icons.auto_awesome_outlined, 'Make a status', 'Text statuses in English or हिन्दी',
                () => context.push(AppRoutes.statusMaker), 0),
            const SizedBox(width: AppSpacing.sm),
            tile(Icons.add_photo_alternate_outlined, 'Import media', 'From Photos or Files, to edit and share',
                () => showImportSheet(context, ref), 1),
          ],
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    );
  }
}

/// Neither supported app is installed: say so plainly. No placeholder source cards.
class _NoWhatsAppCard extends ConsumerWidget {
  const _NoWhatsAppCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            StatusRing(
              size: 88,
              strokeWidth: 5,
              segments: 1,
              color: scheme.outlineVariant,
              child: ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.chat_bubble_outline, size: 36, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No WhatsApp app found', style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'WazApp did not detect WhatsApp or WhatsApp Business on this device, so there are no statuses to show. '
              'Install one of them and come back, or import photos and videos to edit and share.',
              style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: () => showImportSheet(context, ref),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Import from device'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(installedAppsProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Check again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS / platforms without status access.
class _ImportOnlyCard extends ConsumerWidget {
  const _ImportOnlyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waz = context.waz;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        gradient: waz.heroGradient,
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.photo_library_outlined, size: 40, color: waz.onHero),
            const SizedBox(height: AppSpacing.md),
            Text('Bring in your media', style: AppTextStyles.titleLarge.copyWith(color: waz.onHero)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'On this device WazApp cannot look inside WhatsApp. Save a status to Photos from WhatsApp, then import '
              'it here to keep, edit and share it.',
              style: AppTextStyles.bodyMedium.copyWith(color: waz.onHeroMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: waz.signature, foregroundColor: waz.onSignature),
                  onPressed: () => importFlow(context, ref, ImportSource.photos),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Import from Photos'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: waz.onHero,
                    side: BorderSide(color: waz.onHeroMuted),
                  ),
                  onPressed: () => importFlow(context, ref, ImportSource.files),
                  child: const Text('Import from Files'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
