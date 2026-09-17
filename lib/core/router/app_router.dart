// lib/core/router/app_router.dart
//
// go_router setup with all routes: splash, onboarding, permission flow, shell.
// Navigation state survives tab switches (PRD §9).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../di/providers.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/clean/domain/action_models.dart';
import '../../features/clean/presentation/cleanup_success_screen.dart';
import '../../features/clean/presentation/clean_screen.dart';
import '../../features/clean/presentation/category_screen.dart';
import '../../features/clean/presentation/duplicates_screen.dart';
import '../../features/clean/presentation/large_videos_screen.dart';
import '../../features/clean/presentation/screenshots_screen.dart';
import '../../features/clean/presentation/old_media_screen.dart';
import '../../features/clean/presentation/similar_photos_screen.dart';
import '../../features/clean/presentation/blurry_photos_screen.dart';
import '../../features/clean/presentation/swipe_clean_screen.dart';
import '../../features/clean/presentation/voice_notes_screen.dart';
import '../../features/clean/presentation/documents_screen.dart';
import '../../features/analytics/presentation/storage_analytics_screen.dart';
import '../../features/clean/data/all_indexed_media_data_source.dart';
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
  static const allMedia = '/clean/all-media';
  static const duplicates = '/clean/duplicates';
  static const largeVideos = '/clean/large-videos';
  static const screenshots = '/clean/screenshots';
  static const oldMedia = '/clean/old-media';
  static const similarPhotos = '/clean/similar-photos';
  static const blurryPhotos = '/clean/blurry-photos';
  static const swipeClean = '/clean/swipe';
  static const voiceNotes = '/clean/voice-notes';
  static const documents = '/clean/documents';
  static const cleanupSuccess = '/clean/success';
  static const organize = '/organize';
  static const bin = '/bin';
  static const settings = '/settings';
  static const storageAnalytics = '/analytics';

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
              routes: [
                GoRoute(
                  path: 'analytics',
                  builder: (context, state) => const StorageAnalyticsScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.clean,
              builder: (context, state) => const CleanScreen(),
              routes: [
                GoRoute(
                  path: 'all-media',
                  builder: (context, state) => Consumer(
                    builder: (context, ref, _) {
                      final db = ref.watch(appDatabaseProvider);
                      return CategoryScreen(
                        title: 'All Indexed Media',
                        dataSource: AllIndexedMediaDataSource(db),
                      );
                    },
                  ),
                ),
                GoRoute(
                  path: 'duplicates',
                  builder: (context, state) => const DuplicatesScreen(),
                ),
                GoRoute(
                  path: 'large-videos',
                  builder: (context, state) => const LargeVideosScreen(),
                ),
                GoRoute(
                  path: 'screenshots',
                  builder: (context, state) => const ScreenshotsScreen(),
                ),
                GoRoute(
                  path: 'old-media',
                  builder: (context, state) => const OldMediaScreen(),
                ),
                GoRoute(
                  path: 'similar-photos',
                  builder: (context, state) => const SimilarPhotosScreen(),
                ),
                GoRoute(
                  path: 'blurry-photos',
                  builder: (context, state) => const BlurryPhotosScreen(),
                ),
                GoRoute(
                  path: 'swipe',
                  builder: (context, state) => const SwipeCleanScreen(),
                ),
                GoRoute(
                  path: 'voice-notes',
                  builder: (context, state) => const VoiceNotesScreen(),
                ),
                GoRoute(
                  path: 'documents',
                  builder: (context, state) => const DocumentsScreen(),
                ),
                GoRoute(
                  path: 'success',
                  builder: (context, state) => CleanupSuccessScreen(
                    summary: state.extra as CleanupSessionSummary? ??
                        const CleanupSessionSummary(),
                  ),
                ),
              ],
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
