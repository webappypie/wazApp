// lib/features/onboarding/presentation/splash_screen.dart
//
// REQ-ONB-01: Logo, name, tagline. Duration 1.2–1.6s then navigate.
// No fade-in to avoid perception of slowness; instant display.
// Timer is not cancellable — if onboarding check completes faster than
// the minimum, we still wait out the minimum to avoid a flash.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _kMinSplashMs = 1200;
  static const _kMaxSplashMs = 1600;

  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Run the minimum splash and the onboarding check in parallel.
    final results = await Future.wait([
      Future<bool>.delayed(const Duration(milliseconds: _kMinSplashMs), () => true),
      ref.read(onboardingServiceProvider).hasCompletedOnboarding(),
    ]);

    // Ensure we don't exceed the maximum splash duration regardless of how
    // quickly the check completed.
    await Future.delayed(const Duration(milliseconds: _kMaxSplashMs - _kMinSplashMs));

    if (!mounted) return;

    final hasOnboarded = results[1];
    if (hasOnboarded) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon placeholder — Phase 8 replaces with real asset
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xl)),
                ),
                child: Icon(
                  Icons.cleaning_services_rounded,
                  size: 48,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'WappTidy',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: scheme.onPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Clean. Organise. Recover.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: scheme.onPrimary.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
