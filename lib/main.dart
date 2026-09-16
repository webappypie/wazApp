// lib/main.dart
//
// Application entry point for WappTidy.
//
// Responsibilities here (and only here):
//   1. Logger initialisation
//   2. Error boundary installation
//   3. ProviderScope wrapping
//   4. runApp

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/error/error_handler.dart';
import 'core/logging/app_logger.dart';

void main() {
  // Verbose in debug, warning-only in profile/release.
  AppLogger.init(verbose: true);

  WidgetsFlutterBinding.ensureInitialized();

  // Replace the default red-screen error widget.
  ErrorWidget.builder = friendlyErrorWidget;

  runWithErrorBoundary(() {
    runApp(
      const ProviderScope(
        child: WappTidyApp(),
      ),
    );
  });
}
