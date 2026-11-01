// lib/features/status/domain/status_models.dart

import 'package:equatable/equatable.dart';

import '../../library/domain/library_models.dart';

/// The two WhatsApp variants. They are always granted, listed and saved separately.
enum StatusApp {
  whatsapp('whatsapp', 'WhatsApp'),
  business('business', 'WhatsApp Business');

  const StatusApp(this.key, this.label);

  /// Value used on the platform channel and in stored source keys.
  final String key;
  final String label;

  static StatusApp? fromKey(String? key) {
    for (final a in StatusApp.values) {
      if (a.key == key) return a;
    }
    return null;
  }
}

/// A status file that the user has authorised us to read (not yet saved).
class StatusItem extends Equatable {
  const StatusItem({
    required this.app,
    required this.uri,
    required this.name,
    required this.kind,
    required this.mimeType,
    required this.sizeBytes,
    required this.modified,
  });

  final StatusApp app;

  /// Opaque SAF document URI.
  final String uri;
  final String name;
  final MediaKind kind;
  final String mimeType;
  final int sizeBytes;
  final DateTime modified;

  /// Stable identity of this status; used to warn when it is already saved.
  String get sourceKey => '${app.key}:$name:$sizeBytes';

  String get extension {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) {
      return kind == MediaKind.video ? 'mp4' : 'jpg';
    }
    return name.substring(i + 1).toLowerCase();
  }

  @override
  List<Object?> get props => [
    app,
    uri,
    name,
    kind,
    mimeType,
    sizeBytes,
    modified,
  ];
}

/// Outcome of the folder picker.
enum AccessRequestResult { granted, cancelled, wrongFolder }

/// The real state of a source's folder grant (never inferred from the other app's grant).
enum StatusFolderState {
  /// The folder has never been chosen for this app.
  notConfigured,

  /// A grant exists and the status folder can be listed.
  granted,

  /// The user or the system dropped the grant; the folder must be chosen again.
  revoked,

  /// The grant exists but the status folder is gone (app reinstalled, data cleared, never opened).
  folderMissing,
}
