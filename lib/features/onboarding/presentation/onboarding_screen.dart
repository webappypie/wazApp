// lib/features/onboarding/presentation/onboarding_screen.dart
//
// REQ-ONB-02: Onboarding carousel — exactly 3 slides, skip allowed on all.
// Uses Phase 1 components only.
// The last slide navigates to the permission rationale screen (not directly
// to the system dialog — REQ-ONB-03).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/router/app_router.dart';

// ---------------------------------------------------------------------------
// Slide data
// ---------------------------------------------------------------------------

class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    icon: Icons.cleaning_services_rounded,
    title: 'Free up space in seconds',
    body: 'WappTidy finds duplicate photos, large videos, and old media '
        'clogging your WhatsApp storage — all in one place.',
  ),
  _Slide(
    icon: Icons.lock_outline_rounded,
    title: '100% private, on-device',
    body: 'Nothing leaves your phone. No uploads. No accounts. '
        'Your media is analysed entirely on-device.',
  ),
  _Slide(
    icon: Icons.folder_open_outlined,
    title: 'You\'re always in control',
    body: 'Review everything before deleting. Restore items from the Bin. '
        'Protect favourites so they\'re never suggested for removal.',
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToPermissionRationale();
    }
  }

  void _goToPermissionRationale() {
    context.go(AppRoutes.permissionRationale);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button — always visible (REQ-ONB-02)
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _goToPermissionRationale,
                child: Text(
                  'Skip',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            // Slide pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlideWidget(slide: _slides[i]),
              ),
            ),

            // Page indicator + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.lg,
                AppSpacing.pagePadding,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  _PageDots(count: _slides.length, current: _page),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        elevation: AppElevation.none,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.buttonRadius,
                        ),
                      ),
                      child: Text(
                        isLast ? 'Get started' : 'Next',
                        style: AppTextStyles.labelLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide widget
// ---------------------------------------------------------------------------

class _SlideWidget extends StatelessWidget {
  const _SlideWidget({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 56, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            slide.title,
            style: AppTextStyles.headlineSmall.copyWith(color: scheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.body,
            style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page dot indicator
// ---------------------------------------------------------------------------

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Step ${current + 1} of $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: i == current ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current ? scheme.primary : scheme.outlineVariant,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
            ),
            if (i < count - 1) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
