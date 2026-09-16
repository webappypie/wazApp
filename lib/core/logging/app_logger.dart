// lib/core/logging/app_logger.dart
//
// Structured logger for WappTidy.
// Rules:
//   - NEVER use print() anywhere in the codebase. Use AppLogger exclusively.
//   - Log levels: finest/finer/fine/config/info/warning/severe/shout
//   - In production release builds, only warning+ is emitted.
//   - No filenames, file paths, contact names, or media content are ever logged (P-01).
//
// ignore_for_file: avoid_print  ← this is the ONE file where print() is intentional

import 'package:logging/logging.dart';

/// Central logger factory.
///
/// Usage:
///   final _log = AppLogger.get('FeatureName');
///   _log.info('Something happened');
///   _log.warning('Something unexpected', error, stackTrace);
class AppLogger {
  AppLogger._();

  static bool _initialised = false;

  /// Call once from [main] before [runApp].
  static void init({bool verbose = false}) {
    if (_initialised) return;
    _initialised = true;

    Logger.root.level = verbose ? Level.ALL : Level.WARNING;
    Logger.root.onRecord.listen(_handleRecord);
  }

  /// Returns a [Logger] scoped to [name].
  static Logger get(String name) => Logger(name);

  static void _handleRecord(LogRecord record) {
    final level = record.level.name.padRight(7);
    final time = record.time.toIso8601String();
    final name = record.loggerName;
    final msg = record.message;

    // Deliberately compact — no file paths, no media metadata (P-01).
    print('[$time] $level $name: $msg');

    if (record.error != null) {
      print('  ERROR: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('  STACK: ${record.stackTrace}');
    }
  }
}
