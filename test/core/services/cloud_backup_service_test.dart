// test/core/services/cloud_backup_service_test.dart
//
// Unit tests for CloudBackupService and FakeCloudBackupService (REQ-BAK-01..03, P-01..03).

import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/services/backup/cloud_backup_service.dart';
import 'package:wapptidy/core/services/backup/fake_cloud_backup_service.dart';

void main() {
  group('CloudDriveScopes (REQ-BAK-01)', () {
    test('driveFileScope is strictly drive.file and not broad drive scope', () {
      expect(
        CloudDriveScopes.driveFileScope,
        'https://www.googleapis.com/auth/drive.file',
      );
      // Ensure broad scopes are never present
      expect(CloudDriveScopes.driveFileScope.endsWith('/drive'), isFalse);
    });

    test('CloudAccountInfo correctly verifies driveFileScope grant', () {
      const account = CloudAccountInfo(
        email: 'test@gmail.com',
        grantedScopes: [CloudDriveScopes.driveFileScope],
      );
      expect(account.hasDriveFileScope, isTrue);

      const invalidAccount = CloudAccountInfo(
        email: 'test@gmail.com',
        grantedScopes: ['email'],
      );
      expect(invalidAccount.hasDriveFileScope, isFalse);
    });
  });

  group('FakeCloudBackupService (REQ-BAK-01, REQ-BAK-02)', () {
    late FakeCloudBackupService service;

    setUp(() {
      service = FakeCloudBackupService();
    });

    tearDown(() {
      service.dispose();
    });

    test('Initial auth state is disconnected and snapshot is idle', () {
      expect(service.currentAuthStatus, isA<CloudAuthDisconnected>());
      expect(service.currentSnapshot.status, BackupTaskStatus.idle);
      expect(service.currentSnapshot.totalItems, 0);
      expect(service.currentSnapshot.uploadedItems, 0);
    });

    test('Sign in transitions auth state to connected with drive.file scope', () async {
      final events = <CloudAuthStatus>[];
      final sub = service.authStateChanges.listen(events.add);

      final account = await service.signIn();
      expect(account, isNotNull);
      expect(account!.email, 'user@gmail.com');
      expect(account.hasDriveFileScope, isTrue);
      expect(service.currentAuthStatus, isA<CloudAuthConnected>());

      await service.signOut();
      expect(service.currentAuthStatus, isA<CloudAuthDisconnected>());

      await sub.cancel();
      expect(events.length, greaterThanOrEqualTo(2));
    });

    test('startBackup throws if not connected to Google Drive (REQ-BAK-01)', () async {
      final items = [
        const BackupMediaItem(
          id: 1,
          contentUri: 'content://media/1',
          displayName: 'video1.mp4',
          sizeBytes: 1024 * 1024,
          mimeType: 'video/mp4',
          category: 'Video',
        ),
      ];

      expect(
        () => service.startBackup(items: items),
        throwsA(isA<StateError>()),
      );
    });

    test('startBackup uploads items and tracks progress accurately (REQ-BAK-02, P-03)', () async {
      await service.signIn();

      final items = [
        const BackupMediaItem(
          id: 1,
          contentUri: 'content://media/1',
          displayName: 'photo1.jpg',
          sizeBytes: 1000,
          mimeType: 'image/jpeg',
          category: 'Photo',
        ),
        const BackupMediaItem(
          id: 2,
          contentUri: 'content://media/2',
          displayName: 'video1.mp4',
          sizeBytes: 3000,
          mimeType: 'video/mp4',
          category: 'Video',
        ),
      ];

      final snapshots = <BackupProgressSnapshot>[];
      final sub = service.progressStream.listen(snapshots.add);

      await service.startBackup(items: items);

      final finalSnapshot = service.currentSnapshot;
      expect(finalSnapshot.status, BackupTaskStatus.completed);
      expect(finalSnapshot.totalItems, 2);
      expect(finalSnapshot.uploadedItems, 2);
      expect(finalSnapshot.failedItems, 0);
      expect(finalSnapshot.totalBytes, 4000);
      expect(finalSnapshot.uploadedBytes, 4000);
      expect(finalSnapshot.progressRatio, 1.0);
      expect(finalSnapshot.progressPercent, 100);
      expect(finalSnapshot.results.length, 2);
      expect(finalSnapshot.results.every((r) => r.isSuccess), isTrue);

      await sub.cancel();
      expect(snapshots.isNotEmpty, isTrue);
    });

    test('Failed items are recorded and can be retried (REQ-BAK-02)', () async {
      await service.signIn();

      // Configure item 2 to fail
      service.shouldFailItem = (item) => item.id == 2;

      final items = [
        const BackupMediaItem(
          id: 1,
          contentUri: 'content://media/1',
          displayName: 'photo1.jpg',
          sizeBytes: 2000,
          mimeType: 'image/jpeg',
          category: 'Photo',
        ),
        const BackupMediaItem(
          id: 2,
          contentUri: 'content://media/2',
          displayName: 'doc.pdf',
          sizeBytes: 4000,
          mimeType: 'application/pdf',
          category: 'Document',
        ),
      ];

      await service.startBackup(items: items);

      expect(service.currentSnapshot.failedItems, 1);
      expect(service.currentSnapshot.uploadedItems, 1);
      expect(service.currentSnapshot.failedResults.length, 1);
      expect(service.currentSnapshot.failedResults.first.item.id, 2);

      // Now clear failure condition and retry
      service.shouldFailItem = null;
      await service.retryFailed();

      expect(service.currentSnapshot.status, BackupTaskStatus.completed);
      expect(service.currentSnapshot.failedItems, 0);
      expect(service.currentSnapshot.uploadedItems, 2);
      expect(service.currentSnapshot.uploadedBytes, 6000);
    });

    test('Cancel backup stops execution immediately', () async {
      await service.signIn();
      service.simulatedItemDelayMs = 50;

      final items = List.generate(
        10,
        (i) => BackupMediaItem(
          id: i + 1,
          contentUri: 'content://media/${i + 1}',
          displayName: 'file_$i.jpg',
          sizeBytes: 1000,
          mimeType: 'image/jpeg',
          category: 'Photo',
        ),
      );

      final future = service.startBackup(items: items);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      service.cancelBackup();
      await future;

      expect(service.currentSnapshot.status, BackupTaskStatus.cancelled);
      expect(service.currentSnapshot.uploadedItems, lessThan(10));
    });
  });
}
