// lib/integrations/wapcentral/presentation/service_gate.dart
//
// Full-screen, non-dismissible "Service Notice" shown when WAPCentral reports `enabled: false`
// (guide section 9, "Mobile Lifecycle & Operational Rules").
//
//  - Checked at cold start (without delaying the first frame: the app is local-first) and every time
//    the app returns to the foreground.
//  - While blocked, every screen is covered and cannot be interacted with; the Android back button does
//    not dismiss it.
//  - The only action opens the destination URL in the external browser.
//  - When a later check says enabled (or cannot be completed: fail-open) the notice disappears by itself.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/tokens.dart';
import '../service_control_client.dart';
import '../wapcentral_config.dart';

/// Opens a link in the external browser. Abstracted so tests never launch anything.
abstract interface class UrlOpener {
  Future<bool> open(Uri uri);
}

class UrlLauncherOpener implements UrlOpener {
  const UrlLauncherOpener();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final wapCentralConfigProvider = Provider<WapCentralConfig>((ref) => WapCentralConfig.fromEnvironment());

final serviceControlClientProvider = Provider<ServiceControlClient>((ref) {
  final client = ServiceControlClient(config: ref.watch(wapCentralConfigProvider));
  ref.onDispose(client.close);
  return client;
});

final urlOpenerProvider = Provider<UrlOpener>((ref) => const UrlLauncherOpener());

/// Latest known service status. Starts "open" (nothing is blocked before an answer arrives).
class ServiceStatusNotifier extends Notifier<ServiceStatus> {
  bool _inFlight = false;

  @override
  ServiceStatus build() => const ServiceStatus.open(source: StatusSource.initial);

  /// Re-asks WAPCentral. Overlapping calls are collapsed into one.
  Future<void> check() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final next = await ref.read(serviceControlClientProvider).fetch();
      if (ref.mounted) state = next;
    } finally {
      _inFlight = false;
    }
  }
}

final serviceStatusProvider = NotifierProvider<ServiceStatusNotifier, ServiceStatus>(ServiceStatusNotifier.new);

/// Wraps the whole app (placed in MaterialApp.builder) so the notice covers every route.
class ServiceGate extends ConsumerStatefulWidget {
  const ServiceGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ServiceGate> createState() => _ServiceGateState();
}

class _ServiceGateState extends ConsumerState<ServiceGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold start: ask, but do not hold up the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(serviceStatusProvider.notifier).check());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(serviceStatusProvider.notifier).check());
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(serviceStatusProvider);
    final blocked = !status.enabled;
    // Android back is consumed while blocked by WazApp's didPopRoute (PopScope cannot work here: the gate sits
    // above the Navigator, so it has no route to attach to).
    return Stack(
      children: [
        // The app stays mounted (state is kept) but is inert while blocked.
        IgnorePointer(ignoring: blocked, child: ExcludeSemantics(excluding: blocked, child: widget.child)),
        if (blocked) _ServiceNotice(status: status),
      ],
    );
  }
}

class _ServiceNotice extends ConsumerStatefulWidget {
  const _ServiceNotice({required this.status});
  final ServiceStatus status;

  @override
  ConsumerState<_ServiceNotice> createState() => _ServiceNoticeState();
}

class _ServiceNoticeState extends ConsumerState<_ServiceNotice> {
  bool _linkFailed = false;

  Future<void> _open(Uri uri) async {
    final ok = await ref.read(urlOpenerProvider).open(uri);
    if (mounted) setState(() => _linkFailed = !ok);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final scheme = Theme.of(context).colorScheme;
    final uri = s.safeDestination;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.info_outline, color: scheme.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(s.title, style: AppTextStyles.titleLarge)),
                      ]),
                      const SizedBox(height: AppSpacing.md),
                      Text(s.message, style: AppTextStyles.bodyLarge),
                      if (_linkFailed) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('The link could not be opened.', style: AppTextStyles.bodySmall.copyWith(color: scheme.error)),
                      ],
                      if (uri != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(onPressed: () => _open(uri), child: Text(s.buttonText)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
