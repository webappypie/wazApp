// lib/core/router/app_router.dart
//
// go_router setup with all routes: splash, onboarding, permission flow, shell.
// Navigation state survives tab switches (PRD §9).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/clean/presentation/clean_screen.dart';
import '../../features/organize/presentation/organize_screen.dart';
import '../../features/bin/presentation/bin_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/dev/presentation/gallery_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/permission_rationale_screen.dart';
import '../../features/onboarding/presentation/permission_request_screen.dart';
import '../../features/onboarding/presentation/permission_denied_screen.dart';

// Route path constants — single source of truth.
class AppRoutes {
  AppRoutes._();

  // Onboarding / permission flow
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const permissionRationale = '/permission-rationale';
  static const permissionRequest = '/permission-request';
  static const permissionDenied = '/permission-denied';

  // Main shell destinations
  static const home = '/';
  static const clean = '/clean';
  static const organize = '/organize';
  static const bin = '/bin';
  static const settings = '/settings';

  /// Debug-only gallery route. Not reachable in release builds.
  static const devGallery = '/dev/gallery';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  routes: [
    // --- Splash & onboarding ---
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.permissionRationale,
      builder: (context, state) => const PermissionRationaleScreen(),
    ),
    GoRoute(
      path: AppRoutes.permissionRequest,
      builder: (context, state) => const PermissionRequestScreen(),
    ),
    GoRoute(
      path: AppRoutes.permissionDenied,
      builder: (context, state) => const PermissionDeniedScreen(),
    ),

    // --- Debug gallery (kDebugMode guard) ---
    if (kDebugMode)
      GoRoute(
        path: AppRoutes.devGallery,
        builder: (context, state) => const GalleryScreen(),
      ),

    // --- Main shell with persistent bottom nav ---
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.clean,
              builder: (context, state) => const CleanScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.organize,
              builder: (context, state) => const OrganizeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.bin,
              builder: (context, state) => const BinScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Bottom navigation shell — wraps all five main destinations.
class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.cleaning_services_outlined),
            selectedIcon: Icon(Icons.cleaning_services),
            label: 'Clean',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Organize',
          ),
          NavigationDestination(
            icon: Icon(Icons.delete_outlined),
            selectedIcon: Icon(Icons.delete),
            label: 'Bin',
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
