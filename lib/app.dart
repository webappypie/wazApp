// lib/app.dart
//
// Root application widget — WappTidy.
// Wraps the app in ProviderScope (Riverpod) and connects the go_router.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/tokens.dart';
import 'core/router/app_router.dart';
import 'features/settings/presentation/settings_controller.dart';

class WappTidyApp extends ConsumerWidget {
  const WappTidyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp.router(
      title: 'WappTidy',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
    );
  }
}
