// lib/features/private_folder/presentation/private_providers.dart
//
// State for the Private Folder: the optional device-lock setting, the in-memory
// unlocked/locked session, and the item streams.
//
// Security model (also shown to the user):
//  - Items are moved out of the normal library into a separate app-private directory.
//  - Optionally the screen is gated by device authentication.
//  - Files are NOT encrypted. Anyone with root/forensic access, or with an unlocked phone and
//    WazApp's lock switched off, could read them. They are deleted when the app is uninstalled.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../data/device_auth_service.dart';

final deviceAuthServiceProvider = Provider<DeviceAuthService>((ref) => LocalDeviceAuthService());

/// Whether this device can authenticate the user right now (re-read when Settings is opened).
final deviceAuthAvailabilityProvider = FutureProvider.autoDispose<AuthAvailability>(
  (ref) => ref.watch(deviceAuthServiceProvider).availability(),
);

const _kLockKey = 'private_lock_enabled_v1';

/// Whether the Private Folder requires device authentication (default: off, the user opts in).
class PrivateLockSetting extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kLockKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _store(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLockKey, value);
    state = AsyncData(value);
  }

  /// Turns the lock on. The user must pass the prompt first, so a lock that cannot be opened
  /// is never created.
  Future<ToggleResult> enable() async {
    final auth = ref.read(deviceAuthServiceProvider);
    final availability = await auth.availability();
    if (availability != AuthAvailability.available) return ToggleResult.deviceHasNoLock;
    final outcome = await auth.authenticate('Confirm it is you to turn on the Private Folder lock');
    if (outcome != AuthOutcome.success) return ToggleResult.notConfirmed;
    await _store(true);
    ref.read(privateSessionProvider.notifier).markUnlocked();
    return ToggleResult.changed;
  }

  /// Turning the lock off also requires authentication (otherwise anyone holding the unlocked
  /// phone could simply switch it off). If the device no longer has a screen lock there is nothing
  /// to authenticate with, so it can be switched off.
  Future<ToggleResult> disable() async {
    final auth = ref.read(deviceAuthServiceProvider);
    if (await auth.availability() == AuthAvailability.available) {
      final outcome = await auth.authenticate('Confirm it is you to turn off the Private Folder lock');
      if (outcome != AuthOutcome.success) return ToggleResult.notConfirmed;
    }
    await _store(false);
    return ToggleResult.changed;
  }
}

enum ToggleResult { changed, notConfirmed, deviceHasNoLock }

final privateLockSettingProvider =
    AsyncNotifierProvider<PrivateLockSetting, bool>(PrivateLockSetting.new);

enum PrivateAccess { locked, unlocked }

enum UnlockResult {
  /// Authenticated (or no lock is configured).
  unlocked,

  /// The user dismissed or failed the prompt; stays locked.
  cancelled,

  /// The lock is on but the device can no longer authenticate (screen lock removed).
  /// The folder opens, but it is NOT protected, and the UI says so.
  protectionUnavailable,
}

class PrivateSession extends Notifier<PrivateAccess> {
  @override
  PrivateAccess build() => PrivateAccess.locked;

  void markUnlocked() => state = PrivateAccess.unlocked;

  void lock() => state = PrivateAccess.locked;

  Future<UnlockResult> unlock() async {
    final enabled = await ref.read(privateLockSettingProvider.future);
    if (!enabled) {
      state = PrivateAccess.unlocked;
      return UnlockResult.unlocked;
    }
    final auth = ref.read(deviceAuthServiceProvider);
    if (await auth.availability() != AuthAvailability.available) {
      state = PrivateAccess.unlocked;
      return UnlockResult.protectionUnavailable;
    }
    final outcome = await auth.authenticate('Unlock your Private Folder');
    if (outcome == AuthOutcome.success) {
      state = PrivateAccess.unlocked;
      return UnlockResult.unlocked;
    }
    if (outcome == AuthOutcome.notAvailable) {
      state = PrivateAccess.unlocked;
      return UnlockResult.protectionUnavailable;
    }
    return UnlockResult.cancelled;
  }
}

final privateSessionProvider = NotifierProvider<PrivateSession, PrivateAccess>(PrivateSession.new);

/// Items in the Private Folder (only read while the session is unlocked).
final privateItemsProvider = StreamProvider<List<SavedMedia>>(
  (ref) => ref.watch(appDatabaseProvider).watchPrivate(),
);

/// Every item (used by the viewer, which must resolve both normal and private ids).
final allMediaProvider = StreamProvider<List<SavedMedia>>(
  (ref) => ref.watch(appDatabaseProvider).watchAll(),
);
