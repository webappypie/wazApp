// lib/core/services/backup/cloud_backup_service.dart
//
// Cloud Backup Service contract and domain models (REQ-BAK-01, REQ-BAK-02, REQ-BAK-03).
//
// REQ-BAK-01: User-initiated Google Drive backup using the drive.file scope ONLY.
// It is non-sensitive and avoids OAuth restricted-scope verification.
// Never request the full drive scope.

import 'dart:async';

/// Google Drive OAuth scopes used by WappTidy.
class CloudDriveScopes {
  CloudDriveScopes._();

  /// Strictly restricted scope granting access ONLY to files created or opened by WappTidy.
  /// Does NOT grant access to user's personal Google Drive files outside this app.
  /// Avoids restricted-scope verification (REQ-BAK-01).
  static const String driveFileScope = 'https://www.googleapis.com/auth/drive.file';

  /// Standard user profile scope for displaying account identity.
  static const String emailScope = 'email';
}

/// Information about the connected Google account.
class CloudAccountInfo {
  final String email;
  final String? displayName;
  final String? photoUrl;
  final List<String> grantedScopes;

  const CloudAccountInfo({
    required this.email,
    this.displayName,
    this.photoUrl,
    this.grantedScopes = const [CloudDriveScopes.driveFileScope],
  });

  bool get hasDriveFileScope =>
      grantedScopes.contains(CloudDriveScopes.driveFileScope);

  @override
  String toString() => 'CloudAccountInfo(email: $email, name: $displayName)';
}

/// Authentication state with Google Drive.
sealed class CloudAuthStatus {
  const CloudAuthStatus();

  bool get isConnected => this is CloudAuthConnected;
  bool get isAuthenticating => this is CloudAuthAuthenticating;
  CloudAccountInfo? get account =>
      this is CloudAuthConnected ? (this as CloudAuthConnected).account : null;
}

class CloudAuthDisconnected extends CloudAuthStatus {
  const CloudAuthDisconnected();
}

class CloudAuthAuthenticating extends CloudAuthStatus {
  const CloudAuthAuthenticating();
}

class CloudAuthConnected extends CloudAuthStatus {
  @override
  final CloudAccountInfo account;
  const CloudAuthConnected(this.account);
}

class CloudAuthError extends CloudAuthStatus {
  final String message;
  const CloudAuthError(this.message);
}

/// Lifecycle status of an active or completed backup task.
enum BackupTaskStatus {
  idle,
  preparing,
  uploading,
  paused,
  completed,
  failed,
  cancelled,
}

/// A media file item queued for cloud backup.
class BackupMediaItem {
  final int id;
  final String contentUri;
  final String displayName;
  final int sizeBytes;
  final String mimeType;
  final String category;

  const BackupMediaItem({
    required this.id,
    required this.contentUri,
    required this.displayName,
    required this.sizeBytes,
    required this.mimeType,
    required this.category,
  });

  @override
  String toString() =>
      'BackupMediaItem(id: $id, name: $displayName, size: $sizeBytes, cat: $category)';
}

/// Individual item upload result.
class BackupItemResult {
  final BackupMediaItem item;
  final bool isSuccess;
  final String? driveFileId;
  final String? errorMessage;
  final bool canRetry;

  const BackupItemResult({
    required this.item,
    required this.isSuccess,
    this.driveFileId,
    this.errorMessage,
    this.canRetry = true,
  });

  @override
  String toString() =>
      'BackupItemResult(item: ${item.displayName}, success: $isSuccess, error: $errorMessage)';
}

/// Immutable snapshot of backup progress (REQ-BAK-02).
class BackupProgressSnapshot {
  final BackupTaskStatus status;
  final int totalItems;
  final int uploadedItems;
  final int failedItems;
  final int totalBytes;
  final int uploadedBytes;
  final String? currentItemName;
  final List<BackupItemResult> results;
  final String? generalError;

  const BackupProgressSnapshot({
    this.status = BackupTaskStatus.idle,
    this.totalItems = 0,
    this.uploadedItems = 0,
    this.failedItems = 0,
    this.totalBytes = 0,
    this.uploadedBytes = 0,
    this.currentItemName,
    this.results = const [],
    this.generalError,
  });

  double get progressRatio {
    if (totalBytes > 0) {
      return (uploadedBytes / totalBytes).clamp(0.0, 1.0);
    }
    if (totalItems > 0) {
      return (uploadedItems / totalItems).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  int get progressPercent => (progressRatio * 100).round();

  bool get isDone =>
      status == BackupTaskStatus.completed ||
      status == BackupTaskStatus.failed ||
      status == BackupTaskStatus.cancelled;

  bool get isActive =>
      status == BackupTaskStatus.uploading ||
      status == BackupTaskStatus.preparing;

  List<BackupItemResult> get failedResults =>
      results.where((r) => !r.isSuccess).toList();

  List<BackupItemResult> get successResults =>
      results.where((r) => r.isSuccess).toList();

  BackupProgressSnapshot copyWith({
    BackupTaskStatus? status,
    int? totalItems,
    int? uploadedItems,
    int? failedItems,
    int? totalBytes,
    int? uploadedBytes,
    String? currentItemName,
    List<BackupItemResult>? results,
    String? generalError,
  }) {
    return BackupProgressSnapshot(
      status: status ?? this.status,
      totalItems: totalItems ?? this.totalItems,
      uploadedItems: uploadedItems ?? this.uploadedItems,
      failedItems: failedItems ?? this.failedItems,
      totalBytes: totalBytes ?? this.totalBytes,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      currentItemName: currentItemName ?? this.currentItemName,
      results: results ?? this.results,
      generalError: generalError ?? this.generalError,
    );
  }

  @override
  String toString() =>
      'BackupProgressSnapshot(status: $status, $uploadedItems/$totalItems items, $uploadedBytes/$totalBytes bytes)';
}

/// Abstract contract for Google Drive Cloud Backup (REQ-BAK-01, REQ-BAK-02).
abstract class CloudBackupService {
  /// Stream of Google Drive authentication status updates.
  Stream<CloudAuthStatus> get authStateChanges;

  /// Current authentication status.
  CloudAuthStatus get currentAuthStatus;

  /// Initiates user sign-in with Google using `drive.file` scope only (REQ-BAK-01).
  Future<CloudAccountInfo?> signIn();

  /// Signs out of Google Drive.
  Future<void> signOut();

  /// Stream of live progress snapshots during backup (REQ-BAK-02).
  Stream<BackupProgressSnapshot> get progressStream;

  /// Current progress snapshot.
  BackupProgressSnapshot get currentSnapshot;

  /// Starts backing up the provided list of media items.
  Future<void> startBackup({required List<BackupMediaItem> items});

  /// Pauses an ongoing backup task.
  void pauseBackup();

  /// Resumes a paused backup task.
  void resumeBackup();

  /// Cancels an active backup task.
  void cancelBackup();

  /// Retries any failed items from the current/previous session (REQ-BAK-02).
  Future<void> retryFailed();

  /// Cleans up subscriptions and controllers.
  void dispose();
}
