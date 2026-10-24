// lib/features/onboarding/presentation/onboarding_screen.dart
//
// Explains the app before anything is requested (docs/MASTER_PRD.md).
// No permission is asked here: status folders and imports are authorised later,
// in context, by the user choosing a folder or file.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/buttons.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  const _Page(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  static const _pages = [
    _Page(Icons.download_rounded, 'Save',
        'Keep the statuses you have viewed. You choose the folder once; WazApp only reads it and never uploads anything.'),
    _Page(Icons.auto_awesome_outlined, 'Style',
        'Build your own library of photos and videos. Editing and text statuses are coming in upcoming releases.'),
    _Page(Icons.ios_share_rounded, 'Share',
        'Share any saved item from the share sheet, or save a copy to your gallery. You are always in control.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await ref.read(onboardingServiceProvider).markOnboardingComplete();
    } catch (_) {
      // If the flag cannot be stored the intro simply shows again next launch.
    }
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                          child: Icon(p.icon, size: 56, color: scheme.onPrimaryContainer),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(p.title, style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          p.body,
                          style: AppTextStyles.bodyLarge.copyWith(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: PrimaryButton(
                label: last ? 'Get started' : 'Next',
                isLoading: _finishing,
                onPressed: last
                    ? _finish
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md, left: AppSpacing.lg, right: AppSpacing.lg),
              child: Text(
                'Independent app, not affiliated with WhatsApp or Meta.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
