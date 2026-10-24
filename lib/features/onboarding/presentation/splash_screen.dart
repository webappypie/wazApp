// lib/features/onboarding/presentation/splash_screen.dart
//
// Routes to onboarding or home as soon as the (local) onboarding flag is read.
// No artificial delay.

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
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    bool done;
    try {
      done = await ref.read(onboardingServiceProvider).hasCompletedOnboarding();
    } catch (_) {
      done = false;
    }
    if (!mounted) return;
    context.go(done ? AppRoutes.home : AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: kBrandDeepTeal,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppMark(size: 88),
            const SizedBox(height: AppSpacing.lg),
            Text('WazApp',
                style: AppTextStyles.headlineLarge.copyWith(color: scheme.onPrimary == Colors.white ? Colors.white : Colors.white)),
            const SizedBox(height: AppSpacing.sm),
            Text('Save. Style. Share.',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

/// Original WazApp mark: a rounded tile with a download arrow into a "status ring".
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'WazApp logo',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kBrandGreen, kBrandAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Icon(Icons.download_rounded, size: size * 0.55, color: Colors.white),
      ),
    );
  }
}
