// lib/core/services/onboarding/onboarding_service.dart
//
// Tracks whether onboarding has been completed.
// Uses shared_preferences — lightweight, survives process death.

abstract interface class OnboardingService {
  /// True if the user has completed onboarding at least once.
  Future<bool> hasCompletedOnboarding();

  /// Called when the user finishes the onboarding flow.
  Future<void> markOnboardingComplete();
}
