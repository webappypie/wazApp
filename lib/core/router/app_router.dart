// lib/core/router/app_router.dart
//
// go_router setup: splash, onboarding, a three-tab shell (Home / Saved / Settings)
// and full-screen viewers. Tabs for features that do not exist yet (Create,
// Private) are added only when those features ship - no placeholder screens.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/library/presentation/saved_screen.dart';
import '../../features/library/presentation/viewer_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/status/domain/status_models.dart';
import '../../features/status/presentation/home_screen.dart';
import '../../features/status/presentation/status_preview_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const home = '/';
  static const saved = '/saved';
  static const settings = '/settings';
  static const viewer = '/viewer';
  static const statusPreview = '/status-preview';
}

GoRouter buildRouter() => GoRouter(
      initialLocation: AppRoutes.splash,
      routes: [
        GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
        GoRoute(path: AppRoutes.onboarding, builder: (_, _) => const OnboardingScreen()),
        GoRoute(
          path: AppRoutes.viewer,
          builder: (_, state) {
            final args = state.extra;
            if (args is! ViewerArgs) return const _BadRoute();
            return ViewerScreen(args: args);
          },
        ),
        GoRoute(
          path: AppRoutes.statusPreview,
          builder: (_, state) {
            final item = state.extra;
            if (item is! StatusItem) return const _BadRoute();
            return StatusPreviewScreen(item: item);
          },
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.saved, builder: (_, _) => const SavedScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.settings, builder: (_, _) => const SettingsScreen()),
            ]),
          ],
        ),
      ],
    );

/// Shown if a route is opened without its required arguments (e.g. after process death).
class _BadRoute extends StatelessWidget {
  const _BadRoute();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Back to home'),
          ),
        ),
      );
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
