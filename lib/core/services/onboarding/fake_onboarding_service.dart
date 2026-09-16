// lib/core/services/onboarding/fake_onboarding_service.dart
//
// Fake implementation for tests. Defaults to not completed (fresh install).

import 'onboarding_service.dart';

class FakeOnboardingService implements OnboardingService {
  bool _completed;

  FakeOnboardingService({bool startCompleted = false}) : _completed = startCompleted;

  @override
  Future<bool> hasCompletedOnboarding() async => _completed;

  @override
  Future<void> markOnboardingComplete() async => _completed = true;

  void reset() => _completed = false;
}
