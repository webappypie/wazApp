// lib/core/services/background_task/fake_background_task_service.dart
//
// In-memory background task service for tests and development.

import 'background_task_service.dart';

final class FakeBackgroundTaskService implements BackgroundTaskService {
  bool _scheduled = false;
  ScanSchedule? scheduledWith;
  bool? chargingOnly;

  @override
  Future<void> scheduleBackgroundScan({
    required ScanSchedule schedule,
    bool chargingOnly = true,
  }) async {
    _scheduled = true;
    scheduledWith = schedule;
    this.chargingOnly = chargingOnly;
  }

  @override
  Future<void> cancelBackgroundScan() async {
    _scheduled = false;
    scheduledWith = null;
    chargingOnly = null;
  }

  @override
  Future<bool> isBackgroundScanScheduled() async => _scheduled;
}
