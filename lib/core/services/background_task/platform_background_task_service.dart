// lib/core/services/background_task/platform_background_task_service.dart
//
// Native Android WorkManager implementation of BackgroundTaskService (REQ-SET-04, P-02).

import 'package:flutter/services.dart';
import 'background_task_service.dart';

class PlatformBackgroundTaskService implements BackgroundTaskService {
  PlatformBackgroundTaskService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('com.wapptidy/background_work');

  final MethodChannel _channel;

  @override
  Future<void> scheduleBackgroundScan({
    required ScanSchedule schedule,
    bool chargingOnly = true,
  }) async {
    final intervalHours = switch (schedule) {
      ScanSchedule.daily => 24,
      ScanSchedule.everyThreeDays => 72,
      ScanSchedule.weekly => 168,
    };

    await _channel.invokeMethod<void>('scheduleScan', {
      'intervalHours': intervalHours,
      'chargingOnly': chargingOnly,
    });
  }

  @override
  Future<void> cancelBackgroundScan() async {
    await _channel.invokeMethod<void>('cancelScan');
  }

  @override
  Future<bool> isBackgroundScanScheduled() async {
    try {
      final scheduled = await _channel.invokeMethod<bool>('isScheduled');
      return scheduled ?? false;
    } catch (_) {
      return false;
    }
  }
}
