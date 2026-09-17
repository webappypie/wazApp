// lib/core/services/backup/fake_cloud_backup_service.dart
//
// In-memory implementation of CloudBackupService for tests and local development.
// Conforms strictly to REQ-BAK-01, REQ-BAK-02, and P-03 (deterministic math).

import 'dart:async';
import 'cloud_backup_service.dart';

/// In-memory fake of [CloudBackupService].
class FakeCloudBackupService implements CloudBackupService {
  CloudAuthStatus _authStatus = const CloudAuthDisconnected();
  final _authController = StreamController<CloudAuthStatus>.broadcast();

  BackupProgressSnapshot _snapshot = const BackupProgressSnapshot();
  final _progressController = StreamController<BackupProgressSnapshot>.broadcast();

  bool _isPaused = false;
  bool _isCancelled = false;
  Completer<void>? _pauseCompleter;

  /// Optional hook to force specific items to fail for test verification (REQ-BAK-02).
  bool Function(BackupMediaItem item)? shouldFailItem;

  /// Simulated delay per item in milliseconds (default 0 for fast tests).
  int simulatedItemDelayMs = 0;

  FakeCloudBackupService({CloudAuthStatus? initialAuth}) {
    if (initialAuth != null) {
      _authStatus = initialAuth;
    }
  }

  @override
  Stream<CloudAuthStatus> get authStateChanges => _authController.stream;

  @override
  CloudAuthStatus get currentAuthStatus => _authStatus;

  @override
  Stream<BackupProgressSnapshot> get progressStream =>
      _progressController.stream;

  @override
  BackupProgressSnapshot get currentSnapshot => _snapshot;

  @override
  Future<CloudAccountInfo?> signIn() async {
    _setAuth(const CloudAuthAuthenticating());
    if (simulatedItemDelayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: simulatedItemDelayMs));
    }
    const account = CloudAccountInfo(
      email: 'user@gmail.com',
      displayName: 'WhatsApp User',
      grantedScopes: [CloudDriveScopes.driveFileScope, CloudDriveScopes.emailScope],
    );
    _setAuth(const CloudAuthConnected(account));
    return account;
  }

  @override
  Future<void> signOut() async {
    _setAuth(const CloudAuthDisconnected());
  }

  void simulateAuthError(String message) {
    _setAuth(CloudAuthError(message));
  }

  void _setAuth(CloudAuthStatus status) {
    _authStatus = status;
    if (!_authController.isClosed) {
      _authController.add(_authStatus);
    }
  }

  void _emitProgress(BackupProgressSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_progressController.isClosed) {
      _progressController.add(_snapshot);
    }
  }

  @override
  Future<void> startBackup({required List<BackupMediaItem> items}) async {
    if (!_authStatus.isConnected) {
      throw StateError(
          'Cannot start backup without connecting to Google Drive (REQ-BAK-01).');
    }

    _isPaused = false;
    _isCancelled = false;
    _pauseCompleter = null;

    final totalBytes = items.fold<int>(0, (sum, item) => sum + item.sizeBytes);

    _emitProgress(BackupProgressSnapshot(
      status: BackupTaskStatus.preparing,
      totalItems: items.length,
      uploadedItems: 0,
      failedItems: 0,
      totalBytes: totalBytes,
      uploadedBytes: 0,
      results: const [],
    ));

    await _processItems(items, initialResults: []);
  }

  Future<void> _processItems(
    List<BackupMediaItem> itemsToProcess, {
    required List<BackupItemResult> initialResults,
  }) async {
    final results = List<BackupItemResult>.from(initialResults);
    var uploadedCount = results.where((r) => r.isSuccess).length;
    var failedCount = results.where((r) => !r.isSuccess).length;
    var uploadedBytes = results
        .where((r) => r.isSuccess)
        .fold<int>(0, (sum, r) => sum + r.item.sizeBytes);

    for (final item in itemsToProcess) {
      if (_isCancelled) {
        _emitProgress(_snapshot.copyWith(
          status: BackupTaskStatus.cancelled,
          currentItemName: null,
          results: results,
        ));
        return;
      }

      if (_isPaused && _pauseCompleter != null) {
        _emitProgress(_snapshot.copyWith(
          status: BackupTaskStatus.paused,
        ));
        await _pauseCompleter!.future;
        if (_isCancelled) {
          _emitProgress(_snapshot.copyWith(
            status: BackupTaskStatus.cancelled,
            currentItemName: null,
            results: results,
          ));
          return;
        }
      }

      _emitProgress(_snapshot.copyWith(
        status: BackupTaskStatus.uploading,
        currentItemName: item.displayName,
        uploadedItems: uploadedCount,
        failedItems: failedCount,
        uploadedBytes: uploadedBytes,
        results: results,
      ));

      if (simulatedItemDelayMs > 0) {
        await Future<void>.delayed(
            Duration(milliseconds: simulatedItemDelayMs));
      }

      final isFailure = shouldFailItem?.call(item) ?? false;
      if (isFailure) {
        failedCount++;
        results.add(BackupItemResult(
          item: item,
          isSuccess: false,
          errorMessage: 'Upload simulated network timeout',
          canRetry: true,
        ));
      } else {
        uploadedCount++;
        uploadedBytes += item.sizeBytes;
        results.add(BackupItemResult(
          item: item,
          isSuccess: true,
          driveFileId: 'drive_file_${item.id}',
        ));
      }

      _emitProgress(_snapshot.copyWith(
        uploadedItems: uploadedCount,
        failedItems: failedCount,
        uploadedBytes: uploadedBytes,
        results: results,
      ));
    }

    final finalStatus = failedCount > 0
        ? (uploadedCount > 0 ? BackupTaskStatus.completed : BackupTaskStatus.failed)
        : BackupTaskStatus.completed;

    _emitProgress(_snapshot.copyWith(
      status: finalStatus,
      currentItemName: null,
      uploadedItems: uploadedCount,
      failedItems: failedCount,
      uploadedBytes: uploadedBytes,
      results: results,
    ));
  }

  @override
  void pauseBackup() {
    if (_snapshot.status == BackupTaskStatus.uploading) {
      _isPaused = true;
      _pauseCompleter = Completer<void>();
      _emitProgress(_snapshot.copyWith(status: BackupTaskStatus.paused));
    }
  }

  @override
  void resumeBackup() {
    if (_isPaused && _pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      _isPaused = false;
      _pauseCompleter!.complete();
      _pauseCompleter = null;
      _emitProgress(_snapshot.copyWith(status: BackupTaskStatus.uploading));
    }
  }

  @override
  void cancelBackup() {
    _isCancelled = true;
    if (_isPaused && _pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      _pauseCompleter!.complete();
    }
    _emitProgress(_snapshot.copyWith(
      status: BackupTaskStatus.cancelled,
      currentItemName: null,
    ));
  }

  @override
  Future<void> retryFailed() async {
    final failed = _snapshot.failedResults.map((r) => r.item).toList();
    if (failed.isEmpty) return;

    final successfulResults = _snapshot.successResults;

    _isPaused = false;
    _isCancelled = false;
    _pauseCompleter = null;

    _emitProgress(_snapshot.copyWith(
      status: BackupTaskStatus.preparing,
      failedItems: 0,
    ));

    await _processItems(failed, initialResults: successfulResults);
  }

  @override
  void dispose() {
    _authController.close();
    _progressController.close();
  }
}
