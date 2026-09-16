// lib/features/home/presentation/home_screen.dart
// Phase 0 placeholder — real implementation in Phase 4.
// Debug build: shows a "Component Gallery" button for design review.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Home — Phase 4'),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.devGallery),
                child: const Text('Component Gallery'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
