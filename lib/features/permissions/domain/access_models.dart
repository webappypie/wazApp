// lib/features/permissions/domain/access_models.dart
//
// What WazApp needs from the OS and the user, and the real state of each item.
// States are read from the platform on demand; nothing here is remembered as "granted".

import 'package:equatable/equatable.dart';

import '../../status/domain/status_models.dart';

/// Everything shown in Permissions & Access (setup flow and Settings).
enum AccessItem {
  whatsapp,
  whatsappBusiness,
  media,
  notifications,
  locker;

  /// The WhatsApp source behind this item, if it is one.
  StatusApp? get statusApp => switch (this) {
    AccessItem.whatsapp => StatusApp.whatsapp,
    AccessItem.whatsappBusiness => StatusApp.business,
    _ => null,
  };

  static AccessItem forStatusApp(StatusApp app) => app == StatusApp.business
      ? AccessItem.whatsappBusiness
      : AccessItem.whatsapp;
}

enum AccessStatus {
  /// Usable right now.
  granted,

  /// Never requested; the user has not been asked yet.
  notRequested,

  /// Asked and refused; the system may still show its prompt once more.
  denied,

  /// Refused for good, or the OS can no longer prompt: only system settings can change it.
  permanentlyDenied,

  /// The WhatsApp app for this source is not installed.
  notInstalled,

  /// A folder grant existed but was dropped (by the user or the system).
  revoked,

  /// The grant exists but the status folder is gone.
  folderMissing,

  /// This platform/OS version needs no permission for the feature (system pickers do the work).
  notNeeded,

  /// The user must first set something up in system settings (e.g. a screen lock).
  needsSystemSetup,

  /// This device or platform cannot provide it.
  unsupported,
}

extension AccessStatusX on AccessStatus {
  bool get isGranted => this == AccessStatus.granted;

  /// True when nothing is wrong, even though nothing needs granting.
  bool get isOk =>
      this == AccessStatus.granted || this == AccessStatus.notNeeded;
}

class AccessSnapshot extends Equatable {
  const AccessSnapshot(this.item, this.status);

  final AccessItem item;
  final AccessStatus status;

  @override
  List<Object?> get props => [item, status];
}

class AccessOverview extends Equatable {
  const AccessOverview(this.items);

  final Map<AccessItem, AccessSnapshot> items;

  AccessStatus statusOf(AccessItem item) =>
      items[item]?.status ?? AccessStatus.unsupported;

  /// Items worth showing on this platform, in display order.
  List<AccessSnapshot> get visible => [
    for (final i in AccessItem.values)
      if (items[i] != null) items[i]!,
  ];

  @override
  List<Object?> get props => [items];
}

/// What happened after the user pressed an item's action.
enum AccessActionOutcome {
  granted,
  cancelled,
  wrongFolder,
  openedSettings,
  settingsUnavailable,
  notConfirmed,
  needsLockSetup,
  failed,
}
