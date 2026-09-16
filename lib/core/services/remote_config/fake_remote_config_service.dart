// lib/core/services/remote_config/fake_remote_config_service.dart
//
// In-memory remote config with safe defaults for tests and development.
// All ad policy keys default to the most conservative / safest values.

import 'remote_config_service.dart';

final class FakeRemoteConfigService implements RemoteConfigService {
  // Configurable fields — tests can override these directly.
  bool _adsEnabled = false; // Off by default in tests.
  bool _nativeAdsEnabled = false;
  bool _interstitialAdsEnabled = false;
  bool _rewardedAdsEnabled = false;
  int _interstitialSessionCap = 1;
  int _interstitialCooldownMinutes = 30;
  int _nativeMinContentItems = 10;
  int _rewardAdFreeDurationMinutes = 60;
  bool _emergencyAdsKillSwitch = false;

  @override
  Future<void> fetchAndActivate() async {
    // No-op in fake — values stay at whatever the test configured.
  }

  @override
  bool get adsEnabled => _adsEnabled;
  set adsEnabled(bool v) => _adsEnabled = v;

  @override
  bool get nativeAdsEnabled => _nativeAdsEnabled;
  set nativeAdsEnabled(bool v) => _nativeAdsEnabled = v;

  @override
  bool get interstitialAdsEnabled => _interstitialAdsEnabled;
  set interstitialAdsEnabled(bool v) => _interstitialAdsEnabled = v;

  @override
  bool get rewardedAdsEnabled => _rewardedAdsEnabled;
  set rewardedAdsEnabled(bool v) => _rewardedAdsEnabled = v;

  @override
  int get interstitialSessionCap => _interstitialSessionCap;
  set interstitialSessionCap(int v) => _interstitialSessionCap = v;

  @override
  int get interstitialCooldownMinutes => _interstitialCooldownMinutes;
  set interstitialCooldownMinutes(int v) => _interstitialCooldownMinutes = v;

  @override
  int get nativeMinContentItems => _nativeMinContentItems;
  set nativeMinContentItems(int v) => _nativeMinContentItems = v;

  @override
  int get rewardAdFreeDurationMinutes => _rewardAdFreeDurationMinutes;
  set rewardAdFreeDurationMinutes(int v) => _rewardAdFreeDurationMinutes = v;

  @override
  bool get emergencyAdsKillSwitch => _emergencyAdsKillSwitch;
  set emergencyAdsKillSwitch(bool v) => _emergencyAdsKillSwitch = v;
}
