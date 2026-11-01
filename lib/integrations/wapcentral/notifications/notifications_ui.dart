// lib/integrations/wapcentral/notifications/notifications_ui.dart
//
// WAPCentral notification surfaces: the bell with unread badge, the feed screen and the preferences screen.
// Real data only: a build without the platform key shows "not available" instead of sample items.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wap_notifications_sdk/wap_notifications.dart';

import 'notifications_controller.dart';

/// App-bar bell. Shows the real unread count; hidden entirely when notifications are not configured.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    if (state.status == NotificationsStatus.idle || state.status == NotificationsStatus.disabled) {
      return const SizedBox.shrink();
    }
    final unread = state.unreadCount;
    return IconButton(
      tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

/// The notification feed (WAPCentral `GET /notifications`).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.onOpenPreferences});

  /// Opens [NotificationPreferencesScreen]; the host app owns navigation.
  final VoidCallback? onOpenPreferences;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final c = ref.read(notificationsControllerProvider.notifier);
      await c.start();
      await c.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            IconButton(
              tooltip: 'Mark all as read',
              icon: const Icon(Icons.done_all),
              onPressed: () async {
                final ok = await controller.markAllRead();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked as read here; it will sync when you are back online.')),
                  );
                }
              },
            ),
          if (widget.onOpenPreferences != null)
            IconButton(
              tooltip: 'Notification preferences',
              icon: const Icon(Icons.tune),
              onPressed: widget.onOpenPreferences,
            ),
        ],
      ),
      body: _body(state, controller),
    );
  }

  Widget _body(NotificationsState state, NotificationsController controller) {
    switch (state.status) {
      case NotificationsStatus.disabled:
        return _Message(
          icon: Icons.notifications_off_outlined,
          title: 'Notifications are not available',
          body: controller.isNotConfigured
              ? 'This build is not connected to WAPCentral, so there is nothing to show. WazApp works fully without it.'
              : 'Notifications are currently switched off for WazApp.',
        );
      case NotificationsStatus.idle:
      case NotificationsStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case NotificationsStatus.error when state.items.isEmpty:
        return _Message(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load notifications',
          body: 'Check your connection and try again. Everything else in WazApp keeps working offline.',
          action: FilledButton.tonal(onPressed: controller.refresh, child: const Text('Retry')),
        );
      case NotificationsStatus.ready || NotificationsStatus.error:
        if (state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(children: const [
              SizedBox(
                height: 420,
                child: _Message(
                  icon: Icons.notifications_none,
                  title: 'No notifications yet',
                  body: 'Announcements from the WazApp team will appear here.',
                ),
              ),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView.separated(
            itemCount: state.items.length + (state.isStale ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (state.isStale && i == 0) {
                return const ListTile(
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('Showing earlier notifications'),
                  subtitle: Text('Could not refresh. Pull down to try again.'),
                );
              }
              final n = state.items[i - (state.isStale ? 1 : 0)];
              return _NotificationTile(n: n);
            },
          ),
        );
    }
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.n});
  final WapNotification n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(n.isRead ? Icons.notifications_none : Icons.notifications_active, color: n.isRead ? null : scheme.primary),
      title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.w700)),
      subtitle: Text(n.message, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: NotificationsController.linkFor(n) != null ? const Icon(Icons.open_in_new, size: 18) : null,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _NotificationDetail(n: n),
      ).whenComplete(() => ref.read(notificationsControllerProvider.notifier).markRead(n.id)),
    );
  }
}

class _NotificationDetail extends StatelessWidget {
  const _NotificationDetail({required this.n});
  final WapNotification n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = NotificationsController.linkFor(n);
    final image = NotificationsController.imageFor(n);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(n.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(image.toString(), errorBuilder: (_, _, _) => const SizedBox.shrink()),
                ),
              ),
            Text(n.message, style: theme.textTheme.bodyLarge),
            if (link != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open link'),
                onPressed: () async {
                  try {
                    await launchUrl(link, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Category preferences stored on WAPCentral for this device (`wap_notifications_sdk` get/updatePreferences).
/// SYSTEM, SECURITY and MAINTENANCE are mandatory and cannot be turned off.
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends ConsumerState<NotificationPreferencesScreen> {
  NotificationPreferences? _prefs;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = ref.read(notificationsControllerProvider.notifier);
    await c.start();
    final p = await c.loadPreferences();
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _loading = false;
    });
  }

  Future<void> _update(NotificationPreferences next) async {
    final previous = _prefs;
    setState(() {
      _prefs = next;
      _saving = true;
    });
    final ok = await ref.read(notificationsControllerProvider.notifier).savePreferences(next);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _prefs = previous;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Check your connection and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(notificationsControllerProvider.notifier);
    final p = _prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : p == null
              ? _Message(
                  icon: Icons.cloud_off_outlined,
                  title: 'Preferences are not available',
                  body: controller.isNotConfigured
                      ? 'This build is not connected to WAPCentral.'
                      : 'Could not reach WAPCentral. Try again when you are online.',
                  action: controller.isNotConfigured
                      ? null
                      : FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
                )
              : ListView(
                  children: [
                    if (_saving) const LinearProgressIndicator(),
                    SwitchListTile(
                      title: const Text('Notifications'),
                      subtitle: const Text('Turn all optional WazApp notifications on or off.'),
                      value: p.notificationsEnabled,
                      onChanged: (v) => _update(p.copyWith(notificationsEnabled: v)),
                    ),
                    SwitchListTile(
                      title: const Text('Promotions and offers'),
                      value: p.promotionalEnabled,
                      onChanged: p.notificationsEnabled ? (v) => _update(p.copyWith(promotionalEnabled: v)) : null,
                    ),
                    const Divider(),
                    for (final c in _categories(controller))
                      SwitchListTile(
                        title: Text(c.label),
                        subtitle: c.cat.isMandatory ? const Text('Always on: important service messages') : null,
                        value: p.isCategoryEnabled(c.cat),
                        onChanged: c.cat.isMandatory || !p.notificationsEnabled
                            ? null
                            : (v) => _update(p.copyWith(categories: {...p.categories, c.cat.code: v})),
                      ),
                  ],
                ),
    );
  }

  List<({NotificationCategory cat, String label})> _categories(NotificationsController controller) {
    final out = <({NotificationCategory cat, String label})>[];
    for (final f in controller.categories) {
      final cat = NotificationCategory.fromString(f.code);
      if (cat.code == f.code && out.every((e) => e.cat != cat)) out.add((cat: cat, label: f.name));
    }
    return out;
  }
}
