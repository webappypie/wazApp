// lib/core/router/app_router.dart
//
// go_router setup: splash, onboarding, a five-tab shell (Home / Saved / Create /
// Private / Settings) and full-screen viewers and editors.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/create/presentation/create_screen.dart';
import '../../integrations/wapcentral/notifications/notifications_ui.dart';
import '../../features/editor/presentation/photo_editor_screen.dart';
import '../../features/library/presentation/saved_screen.dart';
import '../../features/library/presentation/viewer_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/permissions/presentation/permission_setup_screen.dart';
import '../../features/private_folder/presentation/private_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/status/domain/status_models.dart';
import '../../features/storage_manager/presentation/storage_screen.dart';
import '../../features/status/presentation/home_screen.dart';
import '../../features/status/presentation/source_screen.dart';
import '../../features/status/presentation/status_preview_screen.dart';
import '../../features/video_editor/presentation/video_editor_screen.dart';
import '../../features/status_maker/presentation/status_maker_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const setup = '/setup';
  static const source = '/source';
  static const notifications = '/notifications';
  static const notificationPreferences = '/notification-preferences';
  static const home = '/';
  static const saved = '/saved';
  static const settings = '/settings';
  static const viewer = '/viewer';
  static const statusPreview = '/status-preview';
  static const photoEditor = '/photo-editor';
  static const videoEditor = '/video-editor';
  static const statusMaker = '/status-maker';
  static const create = '/create';
  static const private = '/private';
  static const storage = '/storage';
}

GoRouter buildRouter() => GoRouter(
      initialLocation: AppRoutes.splash,
      routes: [
        GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
        GoRoute(path: AppRoutes.onboarding, builder: (_, _) => const OnboardingScreen()),
        GoRoute(
          path: AppRoutes.notifications,
          builder: (context, _) => NotificationsScreen(
            onOpenPreferences: () => context.push(AppRoutes.notificationPreferences),
          ),
        ),
        GoRoute(path: AppRoutes.notificationPreferences, builder: (_, _) => const NotificationPreferencesScreen()),
        GoRoute(
          path: '${AppRoutes.source}/:key',
          builder: (_, state) {
            final app = StatusApp.fromKey(state.pathParameters['key']);
            return app == null ? const _BadRoute() : SourceScreen(app: app);
          },
        ),
        GoRoute(path: AppRoutes.setup, builder: (_, _) => const PermissionSetupScreen()),
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
        GoRoute(
          path: AppRoutes.photoEditor,
          builder: (_, state) {
            final id = state.extra;
            if (id is! String) return const _BadRoute();
            return PhotoEditorScreen(mediaId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.videoEditor,
          builder: (_, state) {
            final id = state.extra;
            if (id is! String) return const _BadRoute();
            return VideoEditorScreen(mediaId: id);
          },
        ),
        GoRoute(path: AppRoutes.storage, builder: (_, _) => const StorageScreen()),
        GoRoute(path: AppRoutes.statusMaker, builder: (_, _) => const StatusMakerScreen()),
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
              GoRoute(path: AppRoutes.create, builder: (_, _) => const CreateScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.private, builder: (_, _) => const PrivateScreen()),
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
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Create',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline),
            selectedIcon: Icon(Icons.lock),
            label: 'Private',
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
