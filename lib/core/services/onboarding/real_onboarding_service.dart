// lib/core/services/onboarding/real_onboarding_service.dart
//
// Real implementation using shared_preferences.
// This is the only file that imports shared_preferences — all others go through
// the OnboardingService abstraction.

import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding_service.dart';

class RealOnboardingService implements OnboardingService {
  static const _kKey = 'onboarding_complete_v1';

  @override
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKey) ?? false;
  }

  @override
  Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, true);
  }
}
