// lib/features/onboarding/presentation/splash_screen.dart
//
// Branded in-app splash that follows the native launch screen. A three-segment status ring draws
// itself around the mark, then "WazApp" and "Save. Style. Share." reveal word by word.
//
// Startup cost: the animation is ~1.3 s and runs while the (local) onboarding flag is read; routing
// happens as soon as both are done. Tapping skips the rest. With "remove animations" turned on in
// system accessibility settings the final frame is shown at once and routing waits only briefly.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/status_ring.dart';

/// How long the splash is shown at least (tests shorten it).
final splashHoldProvider = Provider<Duration>((ref) => const Duration(milliseconds: 1300));

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1300);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _duration,
  );
  bool _navigated = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.value = 1;
    } else {
      _c.forward();
    }
    final hold = ref.read(splashHoldProvider);
    _route(minimum: reduce && hold > const Duration(milliseconds: 250) ? const Duration(milliseconds: 250) : hold);
  }

  Future<void> _route({required Duration minimum}) async {
    final flag = _readFlag();
    await Future.wait([flag, Future<void>.delayed(minimum)]);
    await _go(await flag);
  }

  Future<bool> _readFlag() async {
    try {
      return await ref.read(onboardingServiceProvider).hasCompletedOnboarding();
    } catch (_) {
      return false;
    }
  }

  Future<void> _go(bool done) async {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go(done ? AppRoutes.home : AppRoutes.onboarding);
  }

  /// Tap to skip the remaining animation.
  Future<void> _skip() async {
    if (_navigated) return;
    _c.value = 1;
    await _go(await _readFlag());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = ['Save.', 'Style.', 'Share.'];
    return Scaffold(
      backgroundColor: kBrandDeepTeal,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kBrandDeepTeal, Color(0xFF053F38)],
            ),
          ),
          child: Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final ring = Curves.easeOutCubic.transform(
                  Interval(0.0, 0.62).transform(_c.value),
                );
                final mark = Curves.easeOutBack.transform(
                  Interval(0.10, 0.50).transform(_c.value),
                );
                final title = Curves.easeOut.transform(
                  Interval(0.45, 0.72).transform(_c.value),
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 152,
                      height: 152,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(152, 152),
                            painter: StatusRingPainter(
                              segments: 3,
                              color: kBrandAccent,
                              trackColor: Colors.white.withValues(alpha: 0.10),
                              progress: ring,
                              strokeWidth: 7,
                              gapRadians: 0.34,
                            ),
                          ),
                          Transform.scale(
                            scale: mark.clamp(0.0, 1.2),
                            child: const AppMark(size: 84),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Opacity(
                      opacity: title,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - title)),
                        child: Text(
                          'WazApp',
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    MergeSemantics(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          for (var i = 0; i < words.length; i++)
                            _Word(
                              text: words[i],
                              t: Interval(0.58 + i * 0.11, 0.78 + i * 0.11).transform(_c.value),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.text, required this.t});
  final String text;
  final double t;

  @override
  Widget build(BuildContext context) {
    final v = Curves.easeOut.transform(t);
    return Opacity(
      opacity: v,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - v)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
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
        child: Icon(
          Icons.download_rounded,
          size: size * 0.55,
          color: Colors.white,
        ),
      ),
    );
  }
}
