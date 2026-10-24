// lib/app.dart
//
// Root application widget - WazApp.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/design/tokens.dart';
import 'core/di/providers.dart';
import 'core/router/app_router.dart';

class WazApp extends ConsumerStatefulWidget {
  const WazApp({super.key});

  @override
  ConsumerState<WazApp> createState() => _WazAppState();
}

class _WazAppState extends ConsumerState<WazApp> {
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
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
