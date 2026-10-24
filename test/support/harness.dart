import 'package:drift/drift.dart' show driftRuntimeOptions;
// Shared widget-test harness: real LibraryService + in-memory Drift + temp storage,
// with only the platform bridge faked.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/core/design/tokens.dart';
import 'package:wazapp/core/di/providers.dart';
import 'package:wazapp/core/services/onboarding/onboarding_service.dart';
import 'package:wazapp/features/library/data/library_storage.dart';
import 'package:wazapp/features/library/data/media_probe.dart';
import 'package:wazapp/features/private_folder/data/device_auth_service.dart';
import 'package:wazapp/features/private_folder/presentation/private_providers.dart';
import 'package:wazapp/features/video_editor/data/video_encoder.dart';
import 'package:wazapp/integrations/wapcentral/presentation/service_gate.dart';
import 'package:wazapp/integrations/wapcentral/service_control_client.dart';
import 'package:wazapp/integrations/wapcentral/wapcentral_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

/// Records links instead of launching a browser.
class FakeUrlOpener implements UrlOpener {
  final List<Uri> opened = [];
  bool succeed = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return succeed;
  }
}

/// A WAPCentral client whose answers the test controls; defaults to "service enabled".
class ScriptedService {
  ScriptedService() {
    client = ServiceControlClient(config: const WapCentralConfig(), httpClient: MockClient((r) async {
      requests++;
      return responder();
    }));
  }

  late final ServiceControlClient client;
  int requests = 0;
  Future<http.Response> Function() responder =
      () async => http.Response('{"success":true,"data":{"enabled":true}}', 200);

  void enable() => responder = () async => http.Response('{"success":true,"data":{"enabled":true}}', 200);

  void disable({String title = 'Service Notice', String message = 'We are doing maintenance.', String? url}) =>
      responder = () async => http.Response(
            '{"success":true,"data":{"enabled":false,"title":"$title","message":"$message",'
            '"buttonText":"Learn More","destinationUrl":"${url ?? 'https://webappypie.com'}"}}',
            200,
          );

  void offline() => responder = () async => throw http.ClientException('offline');
}

/// Scriptable device authentication.
class FakeAuth implements DeviceAuthService {
  FakeAuth({this.availabilityValue = AuthAvailability.available, List<AuthOutcome>? outcomes})
      : outcomes = outcomes ?? [AuthOutcome.success];

  AuthAvailability availabilityValue;

  /// Outcomes returned by successive prompts (the last one repeats).
  final List<AuthOutcome> outcomes;
  final List<String> prompts = [];

  @override
  Future<AuthAvailability> availability() async => availabilityValue;

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    prompts.add(reason);
    final i = prompts.length - 1;
    return outcomes[i < outcomes.length ? i : outcomes.length - 1];
  }
}

class FakeOnboarding implements OnboardingService {
  FakeOnboarding({this.completed = false});
  bool completed;

  @override
  Future<bool> hasCompletedOnboarding() async => completed;

  @override
  Future<void> markOnboardingComplete() async => completed = true;
}

/// Each test owns its own in-memory database; drift's multi-instance warning is noise here.
final bool _driftQuiet = () {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return true;
}();

class Harness {
  Harness._(this.tmp, this.sourceDir, this.db, this.storage, this.access, this.onboarding, this.realProbe,
      this.probe, this.encoder, this.auth, this.service, this.opener);

  /// Use the real image/video decoder instead of the fake probe (for export tests).
  final bool realProbe;

  /// Optional probe / video encoder overrides (video editor tests).
  final MediaProbe? probe;
  final VideoEncoder? encoder;

  /// Device authentication fake (Private Folder tests).
  final DeviceAuthService? auth;

  /// WAPCentral service-control fake and link opener.
  final ScriptedService? service;
  final FakeUrlOpener? opener;

  final Directory tmp;
  final Directory sourceDir;
  final AppDatabase db;
  final LibraryStorage storage;
  final FakeStatusAccess access;
  final FakeOnboarding onboarding;

  static Future<Harness> create(
    WidgetTester tester, {
    FakeStatusAccess? access,
    bool onboarded = true,
    bool realProbe = false,
    MediaProbe? probe,
    VideoEncoder? encoder,
    DeviceAuthService? auth,
    ScriptedService? service,
    FakeUrlOpener? opener,
  }) async {
    // Real file I/O must run outside the fake-async zone of testWidgets.
    final h = await tester.runAsync(() async {
      final tmp = await Directory.systemTemp.createTemp('wazapp_widget_');
      final source = await Directory('${tmp.path}/source').create();
      final storage = LibraryStorage(Directory('${tmp.path}/support'));
      await storage.ensureCreated();
      return (tmp, source, storage);
    });
    assert(_driftQuiet);
    final (tmp, source, storage) = h!;
    return Harness._(
      tmp,
      source,
      AppDatabase(NativeDatabase.memory()),
      storage,
      access ?? FakeStatusAccess(),
      FakeOnboarding(completed: onboarded),
      realProbe,
      probe,
      encoder,
      auth,
      service,
      opener,
    );
  }

  List<Override> get overrides => [
        appDatabaseProvider.overrideWithValue(db),
        libraryStorageProvider.overrideWithValue(storage),
        statusAccessServiceProvider.overrideWithValue(access),
        mediaToolsProvider.overrideWithValue(access),
        mediaProbeProvider.overrideWithValue(probe ?? (realProbe ? const FlutterMediaProbe() : FakeProbe())),
        if (encoder != null) videoEncoderProvider.overrideWithValue(encoder!),
        deviceAuthServiceProvider.overrideWithValue(auth ?? FakeAuth()),
        serviceControlClientProvider.overrideWithValue((service ?? ScriptedService()).client),
        urlOpenerProvider.overrideWithValue(opener ?? FakeUrlOpener()),
        onboardingServiceProvider.overrideWithValue(onboarding),
      ];

  Widget wrap(Widget child) => ProviderScope(
        retry: (_, _) => null,
        overrides: overrides,
        child: MaterialApp(theme: AppTheme.light(), home: child),
      );

  /// App-like host with a router so `context.pop()/go()` work. [initial] is the first location.
  Widget wrapRouter(List<RouteBase> routes, {String initial = '/'}) => ProviderScope(
        retry: (_, _) => null,
        overrides: [
          ...overrides,
          exportTempDirProvider.overrideWithValue(Directory('${tmp.path}/export_tmp')),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: GoRouter(initialLocation: initial, routes: routes),
        ),
      );

  /// Pumps several frames so chained providers resolve. (pumpAndSettle would never
  /// finish: skeleton loaders animate forever.)
  Future<void> settle(WidgetTester tester, [int frames = 10]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Lets real file/db I/O make progress: alternates real time (runAsync) with pumped
  /// frames until [done] returns true or ~5 s elapse.
  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Unmounts the tree so Drift stream timers are cancelled before the test ends.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() async {
      await db.close();
      try {
        await tmp.delete(recursive: true);
      } on FileSystemException {
        // Windows may still hold image handles; the OS temp cleaner removes the directory.
      }
    });
  }
}
