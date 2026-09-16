// lib/app.dart
//
// Root application widget — WappTidy.
// Wraps the app in ProviderScope (Riverpod) and connects the go_router.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';

class WappTidyApp extends ConsumerWidget {
  const WappTidyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'WappTidy',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        // Phase 0: default theme only. Design system tokens applied in Phase 1.
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1C6EF2)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1C6EF2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
    );
  }
}
