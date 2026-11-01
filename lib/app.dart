// lib/app.dart
//
// Root application widget - WazApp.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/design/tokens.dart';
import 'core/di/providers.dart';
import 'core/router/app_router.dart';
import 'features/permissions/presentation/access_controller.dart';
import 'features/private_folder/presentation/private_providers.dart';
import 'integrations/wapcentral/presentation/service_gate.dart';
import 'integrations/wapcentral/ads/ads_controller.dart';
import 'integrations/wapcentral/ads/full_screen_ads.dart';
import 'integrations/wapcentral/wap_startup.dart';

class WazApp extends ConsumerStatefulWidget {
  const WazApp({super.key});

  @override
  ConsumerState<WazApp> createState() => _WazAppState();
}

class _WazAppState extends ConsumerState<WazApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // WAPCentral modules (ads, notifications, promotions) start after the first frame and never block launch.
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(wapStartupProvider).start());
  }

  /// While WAPCentral has paused the service the notice cannot be dismissed, and Android back must neither close
  /// the app nor navigate the screens hidden beneath it. This observer is registered before the Navigator's own
  /// (WazApp is an ancestor of it), so it sees the back press first.
  @override
  Future<bool> didPopRoute() async => !ref.read(serviceStatusProvider).enabled;

  /// The Private Folder re-locks whenever WazApp leaves the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      ref.read(privateSessionProvider.notifier).lock();
    }
    if (state == AppLifecycleState.paused) ref.read(fullScreenAdsProvider).onBackgrounded();
    if (state == AppLifecycleState.resumed) {
      ref.read(wapStartupProvider).onResume();
      _maybeAppOpenAd();
    }
    // Permissions can change in system settings while WazApp is in the background: re-read them.
    if (state == AppLifecycleState.resumed && ref.exists(accessOverviewProvider)) {
      ref.read(accessOverviewProvider.notifier).refresh();
    }
  }

  /// App-open ad after a long absence (see FullScreenAds for every rule). Waits a moment so the config refresh
  /// that onResume starts, and the first frame, are done.
  Future<void> _maybeAppOpenAd() async {
    if (!ref.read(adsControllerProvider)) return; // ads off or not started: no timer, no work
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final context = _router.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final route = _router.routerDelegate.currentConfiguration.uri.path;
    await ref.read(fullScreenAdsProvider).onResumed(context, route: route, blocked: !ref.read(serviceStatusProvider).enabled);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'WazApp',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      // WAPCentral remote service control: covers every route when the service is paused.
      builder: (context, child) => ServiceGate(child: child ?? const SizedBox.shrink()),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
    );
  }
}
