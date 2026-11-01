// lib/features/permissions/presentation/access_controller.dart
//
// Single source of truth for "what can WazApp do right now". Every state comes from a fresh
// OS/native read; actions go through the platform API that owns the permission.

import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_error.dart';
import '../../../integrations/wapcentral/notifications/notifications_controller.dart';
import '../../private_folder/data/device_auth_service.dart';
import '../../private_folder/presentation/private_providers.dart';
import '../../status/domain/status_models.dart';
import '../../status/presentation/status_providers.dart';
import '../data/permission_gateway.dart';
import '../domain/access_models.dart';

final permissionGatewayProvider = Provider<PermissionGateway>(
  (ref) => PlatformPermissionGateway(),
);

/// Called after notification permission is granted so push registration can start. The default does
/// registers the device with WAPCentral (only ever while the permission is granted).
final notificationsGrantedHookProvider = Provider<Future<void> Function()>(
  (ref) => () => ref.read(notificationsControllerProvider.notifier).syncRegistration(),
);

final accessOverviewProvider =
    AsyncNotifierProvider<AccessOverviewController, AccessOverview>(
      AccessOverviewController.new,
    );

class AccessOverviewController extends AsyncNotifier<AccessOverview> {
  @override
  Future<AccessOverview> build() {
    // Turning the Private Folder lock on/off elsewhere (Settings) must update this view too.
    ref.watch(privateLockSettingProvider);
    return _compute();
  }

  Future<AccessOverview> _compute() async {
    final status = ref.read(statusAccessServiceProvider);
    final gateway = ref.read(permissionGatewayProvider);
    final map = <AccessItem, AccessSnapshot>{};

    if (status.isSupported) {
      final installed = await status.installedApps();
      for (final app in StatusApp.values) {
        final item = AccessItem.forStatusApp(app);
        if (installed[app] != true) {
          map[item] = AccessSnapshot(item, AccessStatus.notInstalled);
          continue;
        }
        final s = switch (await status.folderState(app)) {
          StatusFolderState.granted => AccessStatus.granted,
          StatusFolderState.notConfigured => AccessStatus.notRequested,
          StatusFolderState.revoked => AccessStatus.revoked,
          StatusFolderState.folderMissing => AccessStatus.folderMissing,
        };
        map[item] = AccessSnapshot(item, s);
      }
    }

    // Photos and files: WazApp only uses system pickers and MediaStore inserts, which need no permission.
    map[AccessItem.media] = const AccessSnapshot(
      AccessItem.media,
      AccessStatus.notNeeded,
    );

    map[AccessItem.notifications] = AccessSnapshot(
      AccessItem.notifications,
      await gateway.notificationStatus(),
    );

    final availability = await ref
        .read(deviceAuthServiceProvider)
        .availability();
    final lockOn = await ref.read(privateLockSettingProvider.future);
    final lock = switch (availability) {
      AuthAvailability.available =>
        lockOn ? AccessStatus.granted : AccessStatus.notRequested,
      AuthAvailability.notEnrolled => AccessStatus.needsSystemSetup,
      // local_auth reports "not supported" when no screen lock exists; Android phones can nearly always set one.
      AuthAvailability.unsupported =>
        Platform.isAndroid
            ? AccessStatus.needsSystemSetup
            : AccessStatus.unsupported,
    };
    map[AccessItem.locker] = AccessSnapshot(AccessItem.locker, lock);
    return AccessOverview(map);
  }

  /// Re-reads everything without flashing a loading state (app resume, "Check again").
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_compute);
    if (!ref.mounted) return;
    state = next;
  }

  void _invalidateStatus(StatusApp app) {
    ref.invalidate(installedAppsProvider);
    ref.invalidate(statusAccessProvider(app));
    ref.invalidate(statusFolderStateProvider(app));
    ref.invalidate(statusListProvider(app));
  }

  /// Runs the item's grant/configure action. Returns what actually happened.
  Future<AccessActionOutcome> act(AccessItem item) async {
    try {
      switch (item) {
        case AccessItem.whatsapp:
        case AccessItem.whatsappBusiness:
          final app = item.statusApp!;
          final r = await ref
              .read(statusAccessServiceProvider)
              .requestAccess(app);
          _invalidateStatus(app);
          await refresh();
          return switch (r) {
            AccessRequestResult.granted => AccessActionOutcome.granted,
            AccessRequestResult.cancelled => AccessActionOutcome.cancelled,
            AccessRequestResult.wrongFolder => AccessActionOutcome.wrongFolder,
          };
        case AccessItem.notifications:
          final gateway = ref.read(permissionGatewayProvider);
          final current = await gateway.notificationStatus();
          if (current == AccessStatus.permanentlyDenied) {
            final ok = await gateway.openSettings(SettingsPage.notifications);
            return ok
                ? AccessActionOutcome.openedSettings
                : AccessActionOutcome.settingsUnavailable;
          }
          final after = await gateway.requestNotifications();
          await refresh();
          if (after == AccessStatus.granted) {
            await ref.read(notificationsGrantedHookProvider)();
            return AccessActionOutcome.granted;
          }
          return AccessActionOutcome.cancelled;
        case AccessItem.locker:
          if (state.value?.statusOf(AccessItem.locker) ==
              AccessStatus.needsSystemSetup) {
            final ok = await ref
                .read(permissionGatewayProvider)
                .openSettings(SettingsPage.security);
            return ok
                ? AccessActionOutcome.openedSettings
                : AccessActionOutcome.settingsUnavailable;
          }
          final r = await ref
              .read(privateLockSettingProvider.notifier)
              .enable();
          await refresh();
          return switch (r) {
            ToggleResult.changed => AccessActionOutcome.granted,
            ToggleResult.notConfirmed => AccessActionOutcome.notConfirmed,
            ToggleResult.deviceHasNoLock => AccessActionOutcome.needsLockSetup,
          };
        case AccessItem.media:
          return AccessActionOutcome.granted;
      }
    } on AppError {
      await refresh();
      return AccessActionOutcome.failed;
    }
  }

  /// Opens the system page that owns [item]'s permission (used by "Open settings" actions).
  Future<AccessActionOutcome> openSystemSettings(AccessItem item) async {
    final page = switch (item) {
      AccessItem.notifications => SettingsPage.notifications,
      AccessItem.locker => SettingsPage.security,
      _ => SettingsPage.app,
    };
    final ok = await ref.read(permissionGatewayProvider).openSettings(page);
    return ok
        ? AccessActionOutcome.openedSettings
        : AccessActionOutcome.settingsUnavailable;
  }

  /// Turns the Private Folder lock off (requires authentication).
  Future<AccessActionOutcome> disableLocker() async {
    final r = await ref.read(privateLockSettingProvider.notifier).disable();
    await refresh();
    return r == ToggleResult.changed
        ? AccessActionOutcome.granted
        : AccessActionOutcome.notConfirmed;
  }

  /// Forgets the folder grant for [app].
  Future<void> removeFolder(StatusApp app) async {
    await ref.read(statusAccessServiceProvider).revokeAccess(app);
    _invalidateStatus(app);
    await refresh();
  }
}
