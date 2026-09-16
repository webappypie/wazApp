// lib/core/services/analytics/fake_analytics_service.dart
//
// In-memory analytics implementation for tests and development.
// Records all calls so tests can assert which events were logged.

import 'analytics_service.dart';

final class FakeAnalyticsService implements AnalyticsService {
  final List<({AnalyticsEvent event, Map<String, Object>? params})> recorded =
      [];
  final List<({String name, String value})> recordedProperties = [];

  @override
  Future<void> logEvent(
    AnalyticsEvent event, {
    Map<String, Object>? params,
  }) async {
    recorded.add((event: event, params: params));
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    recordedProperties.add((name: name, value: value));
  }

  void reset() {
    recorded.clear();
    recordedProperties.clear();
  }
}
