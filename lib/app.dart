// lib/app.dart
//
// Root application widget - WazApp.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/design/tokens.dart';
import 'core/di/providers.dart';
import 'core/router/app_router.dart';
import 'features/private_folder/presentation/private_providers.dart';

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
  }

  /// The Private Folder re-locks whenever WazApp leaves the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      ref.read(privateSessionProvider.notifier).lock();
    }
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
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
    );
  }
}
