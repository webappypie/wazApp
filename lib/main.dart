// lib/main.dart
//
// Application entry point for WazApp.
//   1. Logger + error boundary
//   2. Open local library storage (the only async startup work; no network)
//   3. ProviderScope + runApp

import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/di/providers.dart';
import 'core/error/error_handler.dart';
import 'core/logging/app_logger.dart';
import 'features/library/data/library_storage.dart';

/// Makes the bundled fonts' SIL OFL licence texts show up in the app's licence page.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final family in ['hind', 'tirodevanagarihindi', 'kalam', 'rozhaone', 'poppins', 'pacifico']) {
      final text = await rootBundle.loadString('assets/licenses/OFL-$family.txt');
      yield LicenseEntryWithLineBreaks(['Font: $family (SIL Open Font License 1.1)'], text);
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init(verbose: false);
  ErrorWidget.builder = friendlyErrorWidget;
  _registerFontLicenses();

  final storage = await LibraryStorage.open();
  await storage.ensureCreated();
  await storage.cleanPartialFiles();

  runWithErrorBoundary(() {
    runApp(
      ProviderScope(
        // Riverpod 3 retries failed providers silently; we surface errors immediately instead.
        retry: (_, _) => null,
        overrides: [libraryStorageProvider.overrideWithValue(storage)],
        child: const WazApp(),
      ),
    );
  });
}
