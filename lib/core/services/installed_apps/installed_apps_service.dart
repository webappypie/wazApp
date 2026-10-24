// lib/core/services/installed_apps/installed_apps_service.dart
//
// Detects whether WhatsApp and/or WhatsApp Business are installed on the device.
// Handles all 4 states:
//   - WhatsApp installed only
//   - WhatsApp Business installed only
//   - Both installed
//   - Neither installed

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

import '../media_access/media_item.dart';

/// Installation state of supported messaging applications.
class InstalledSources extends Equatable {
  const InstalledSources({
    this.isWhatsAppInstalled = false,
    this.isWhatsAppBusinessInstalled = false,
  });

  final bool isWhatsAppInstalled;
  final bool isWhatsAppBusinessInstalled;

  bool get hasBoth => isWhatsAppInstalled && isWhatsAppBusinessInstalled;
  bool get hasAny => isWhatsAppInstalled || isWhatsAppBusinessInstalled;
  bool get isWhatsAppOnly => isWhatsAppInstalled && !isWhatsAppBusinessInstalled;
  bool get isBusinessOnly => !isWhatsAppInstalled && isWhatsAppBusinessInstalled;
  bool get isNeither => !isWhatsAppInstalled && !isWhatsAppBusinessInstalled;

  List<MediaSource> get installedList => [
        if (isWhatsAppInstalled) MediaSource.whatsApp,
        if (isWhatsAppBusinessInstalled) MediaSource.whatsAppBusiness,
      ];

  static const both = InstalledSources(
    isWhatsAppInstalled: true,
    isWhatsAppBusinessInstalled: true,
  );

  static const whatsAppOnly = InstalledSources(
    isWhatsAppInstalled: true,
    isWhatsAppBusinessInstalled: false,
  );

  static const businessOnly = InstalledSources(
    isWhatsAppInstalled: false,
    isWhatsAppBusinessInstalled: true,
  );

  static const neither = InstalledSources(
    isWhatsAppInstalled: false,
    isWhatsAppBusinessInstalled: false,
  );

  @override
  List<Object?> get props => [isWhatsAppInstalled, isWhatsAppBusinessInstalled];

  @override
  String toString() =>
      'InstalledSources(wa=$isWhatsAppInstalled, w4b=$isWhatsAppBusinessInstalled)';
}

/// Abstract interface for detecting installed messaging apps.
abstract interface class InstalledAppsService {
  Future<InstalledSources> detectInstalledSources();
}

/// Native implementation via platform channel.
class PlatformInstalledAppsService implements InstalledAppsService {
  PlatformInstalledAppsService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('com.wapptidy/media_indexer');

  final MethodChannel _channel;

  @override
  Future<InstalledSources> detectInstalledSources() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('detectInstalledSources');
      if (res != null) {
        return InstalledSources(
          isWhatsAppInstalled: res['whatsapp'] == true,
          isWhatsAppBusinessInstalled: res['whatsappBusiness'] == true,
        );
      }
    } catch (_) {
      // Fallback for non-Android environments or channel errors
    }
    // Default fallback: assume WhatsApp is installed
    return InstalledSources.whatsAppOnly;
  }
}

/// Test/Mock implementation for unit tests and local development.
class FakeInstalledAppsService implements InstalledAppsService {
  FakeInstalledAppsService({
    this.installedSources = InstalledSources.both,
  });

  InstalledSources installedSources;

  @override
  Future<InstalledSources> detectInstalledSources() async {
    return installedSources;
  }
}
