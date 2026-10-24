// lib/core/error/error_handler.dart
//
// Global error boundary and uncaught-exception hook.
// Wraps the app widget, catches Flutter framework errors, and reports
// PlatformDispatcher errors. Never surfaces raw exception text to the user.

import 'dart:async';

import 'package:flutter/material.dart';

import '../logging/app_logger.dart';

final _log = AppLogger.get('ErrorHandler');

/// Wraps [runApp] with global error catching.
///
/// Usage in main.dart:
///   runWithErrorBoundary(() => runApp(const WazAppApp()));
void runWithErrorBoundary(void Function() body) {
  // Zone-level errors (async exceptions not caught anywhere else).
  runZonedGuarded(
    () {
      // Flutter framework errors (widget build failures, etc.)
      FlutterError.onError = (FlutterErrorDetails details) {
        _log.severe(
          'Flutter framework error in ${details.library ?? 'unknown'}',
          details.exception,
          details.stack,
        );
        // In debug: still show red error widget. In release: fail silently.
        if (details.silent) return;
        FlutterError.presentError(details);
      };

      body();
    },
    (Object error, StackTrace stack) {
      _log.severe('Uncaught async error', error, stack);
    },
  );
}

/// A Flutter [ErrorWidget.builder] replacement that shows a user-friendly
/// error card instead of a raw exception stack trace.
///
/// Set once in main: `ErrorWidget.builder = friendlyErrorWidget;`
Widget friendlyErrorWidget(FlutterErrorDetails details) {
  _log.warning('ErrorWidget triggered: ${details.exceptionAsString()}');
  return Container(
    color: Colors.white,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        const Text(
          'Something went wrong',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Restart the app if this persists.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
