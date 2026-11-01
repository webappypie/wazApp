import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wap_notifications_sdk/wap_notifications.dart';
import 'package:wazapp/integrations/wapcentral/notifications/notification_backend.dart';
import 'package:wazapp/integrations/wapcentral/notifications/notifications_controller.dart';
import 'package:wazapp/integrations/wapcentral/notifications/notifications_ui.dart';
import 'package:wazapp/integrations/wapcentral/notifications/push_gateway.dart';
import 'package:wazapp/integrations/wapcentral/notifications/wap_notification_api.dart';

WapNotification _n(String id, {bool read = false, DateTime? at, String? link}) => WapNotification(
      id: id,
      title: 'Title $id',
      message: 'Body $id',
      isRead: read,
      createdAt: at ?? DateTime(2026, 10, 25, 10, int.tryParse(id) ?? 0),
      externalUrl: link,
    );

class _FakeBackend implements NotificationBackend {
  _FakeBackend({this.configured = true});
  bool configured;
  bool suppressed = false;
  bool offline = false;
  bool readOk = true;
  List<WapNotification> feed = [];
  final registered = <String>[];
  final readCalls = <String>[];
  int inits = 0;
  NotificationPreferences prefs = const NotificationPreferences();
  NotificationPreferences? saved;

  @override
  bool get isConfigured => configured;
  @override
  bool get isSuppressed => suppressed;
  @override
  List<FeedCategory> get categories => const [FeedCategory('UPDATE', 'Updates'), FeedCategory('SECURITY', 'Security')];
  @override
  Future<void> initialize({required String deviceId}) async => inits++;
  @override
  Future<List<WapNotification>> fetch() async {
    if (offline) throw const NotificationsUnavailableException('network');
    return feed;
  }

  @override
  Future<bool> markRead(String id) async {
    readCalls.add(id);
    return readOk;
  }

  @override
  Future<bool> markAllRead() async => readOk;
  @override
  Future<bool> registerPushToken(String token, {required String platform}) async {
    registered.add(token);
    return true;
  }

  @override
  Future<NotificationPreferences> getPreferences() async => prefs;
  @override
  Future<bool> updatePreferences(NotificationPreferences p) async {
    if (offline) return false;
    saved = p;
    return true;
  }

  @override
  WapNotification fromPush(Map<String, dynamic> payload) => WapNotification.fromFcmPayload(payload);
}

class _FakePush implements PushGateway {
  bool available = true;
  bool granted = false;
  String? tokenValue = 'tok-1';
  int tokenCalls = 0;
  final foreground = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Future<bool> initialize() async => available;
  @override
  Future<bool> isPermissionGranted() async => granted;
  @override
  Future<String?> token() async {
    tokenCalls++;
    return tokenValue;
  }

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => foreground.stream;
  @override
  Stream<Map<String, dynamic>> get onMessageOpened => const Stream.empty();
  @override
  Future<Map<String, dynamic>?> initialMessage() async => null;
}

ProviderContainer _make(_FakeBackend b, _FakePush p) {
  final c = ProviderContainer(overrides: [
    notificationBackendProvider.overrideWithValue(b),
    pushGatewayProvider.overrideWithValue(p),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('NotificationsController', () {
    test('no key => disabled, nothing registered or fetched', () async {
      final b = _FakeBackend(configured: false);
      final p = _FakePush()..granted = true;
      final c = _make(b, p);
      await c.read(notificationsControllerProvider.notifier).start();
      expect(c.read(notificationsControllerProvider).status, NotificationsStatus.disabled);
      expect(b.inits, 0);
      expect(b.registered, isEmpty);
      expect(await c.read(notificationsControllerProvider.notifier).syncRegistration(), isFalse);
    });

    test('feed loads newest first with a real unread count', () async {
      final b = _FakeBackend()..feed = [_n('1'), _n('3'), _n('2', read: true)];
      final c = _make(b, _FakePush());
      await c.read(notificationsControllerProvider.notifier).start();
      final s = c.read(notificationsControllerProvider);
      expect(s.status, NotificationsStatus.ready);
      expect(s.items.map((e) => e.id), ['3', '2', '1']);
      expect(s.unreadCount, 2);
    });

    test('no token is registered while the OS permission is not granted; granting registers once', () async {
      final b = _FakeBackend();
      final p = _FakePush();
      final c = _make(b, p);
      final n = c.read(notificationsControllerProvider.notifier);
      await n.start();
      expect(b.registered, isEmpty);
      expect(p.tokenCalls, 0);

      p.granted = true; // user allowed notifications in the permission screen
      expect(await n.syncRegistration(), isTrue);
      expect(await n.syncRegistration(), isTrue);
      expect(b.registered, ['tok-1']);
      expect(c.read(notificationsControllerProvider).pushRegistered, isTrue);
    });

    test('push unavailable (no Play services) never throws', () async {
      final p = _FakePush()
        ..available = false
        ..granted = true;
      final c = _make(_FakeBackend(), p);
      expect(await c.read(notificationsControllerProvider.notifier).syncRegistration(), isFalse);
    });

    test('offline refresh keeps the last feed and marks it stale', () async {
      final b = _FakeBackend()..feed = [_n('1')];
      final c = _make(b, _FakePush());
      final n = c.read(notificationsControllerProvider.notifier);
      await n.start();
      b.offline = true;
      await n.refresh();
      final s = c.read(notificationsControllerProvider);
      expect(s.status, NotificationsStatus.error);
      expect(s.isStale, isTrue);
      expect(s.items, hasLength(1));
    });

    test('markRead is optimistic; an unconfirmed read stays pending and survives a refresh', () async {
      final b = _FakeBackend()
        ..feed = [_n('1')]
        ..readOk = false;
      final c = _make(b, _FakePush());
      final n = c.read(notificationsControllerProvider.notifier);
      await n.start();
      expect(await n.markRead('1'), isFalse);
      expect(c.read(notificationsControllerProvider).unreadCount, 0);
      await n.refresh(); // server still says unread
      expect(c.read(notificationsControllerProvider).unreadCount, 0);
      expect(b.readCalls, isNotEmpty);
    });

    test('kill switch from WAPCentral empties the feed', () async {
      final b = _FakeBackend()..feed = [_n('1')];
      final c = _make(b, _FakePush());
      final n = c.read(notificationsControllerProvider.notifier);
      await n.start();
      b.suppressed = true;
      await n.refresh();
      expect(c.read(notificationsControllerProvider).status, NotificationsStatus.disabled);
      expect(c.read(notificationsControllerProvider).items, isEmpty);
    });

    test('foreground push is added to the feed once', () async {
      final b = _FakeBackend();
      final p = _FakePush()..granted = true;
      final c = _make(b, p);
      final n = c.read(notificationsControllerProvider.notifier);
      await n.start();
      await n.syncRegistration();
      final payload = {
        'data': {'notificationId': 'push-1'},
        'notification': {'title': 'Hello', 'body': 'World'},
      };
      p.foreground.add(payload);
      p.foreground.add(payload);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(notificationsControllerProvider).items.where((e) => e.title == 'Hello'), hasLength(1));
    });

    test('links: only https (or bare hosts) are ever opened', () {
      expect(NotificationsController.linkFor(_n('1', link: 'https://a.example/x')).toString(), 'https://a.example/x');
      expect(NotificationsController.linkFor(_n('1', link: 'webappypie.com')).toString(), 'https://webappypie.com');
      expect(NotificationsController.linkFor(_n('1', link: 'javascript:alert(1)')), isNull);
      expect(NotificationsController.linkFor(_n('1', link: 'intent://x#Intent;end')), isNull);
      expect(NotificationsController.linkFor(_n('1', link: 'http://insecure.example')), isNull);
    });
  });

  group('WAPCentral feed contract', () {
    test('live shape data.items with read flag is parsed', () {
      final r = WapNotificationApi.parseFeedPage(
          '{"success":true,"data":{"items":[{"id":"a","title":"T","message":"M","read":true},'
          '{"id":"b","title":"T2","message":"M2"},{"broken":1}],"total":3}}');
      expect(r.items.map((e) => e.id), ['a', 'b']);
      expect(r.items.first.isRead, isTrue);
      expect(r.total, 3);
    });

    test('malformed body throws instead of looking like an empty feed', () {
      expect(() => WapNotificationApi.parseFeedPage('<html>'), throwsA(isA<NotificationsUnavailableException>()));
    });
  });

  group('UI', () {
    Future<void> pump(WidgetTester t, ProviderContainer c, Widget home) => t.pumpWidget(
          UncontrolledProviderScope(container: c, child: MaterialApp(home: home)),
        );

    testWidgets('not configured: honest message, no sample items, no bell', (tester) async {
      final c = _make(_FakeBackend(configured: false), _FakePush());
      await pump(tester, c, const NotificationsScreen());
      await tester.pumpAndSettle();
      expect(find.text('Notifications are not available'), findsOneWidget);
      await pump(tester, c, Scaffold(appBar: AppBar(actions: [NotificationBellButton(onPressed: () {})])));
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    });

    testWidgets('empty feed state', (tester) async {
      final c = _make(_FakeBackend(), _FakePush());
      await pump(tester, c, const NotificationsScreen());
      await tester.pumpAndSettle();
      expect(find.text('No notifications yet'), findsOneWidget);
    });

    testWidgets('offline error state with retry', (tester) async {
      final b2 = _FakeBackend()..offline = true;
      final c2 = _make(b2, _FakePush());
      await pump(tester, c2, const NotificationsScreen());
      await tester.pumpAndSettle();
      expect(find.text('Could not load notifications'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('items and bell badge reflect real unread count', (tester) async {
      final b = _FakeBackend()..feed = [_n('1'), _n('2', read: true)];
      final c = _make(b, _FakePush());
      await pump(tester, c, const NotificationsScreen());
      await tester.pumpAndSettle();
      expect(find.text('Title 1'), findsOneWidget);
      expect(find.text('Title 2'), findsOneWidget);
      await pump(tester, c, Scaffold(appBar: AppBar(actions: [NotificationBellButton(onPressed: () {})])));
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('preferences: mandatory categories are locked, change is saved, failure rolls back', (tester) async {
      final b = _FakeBackend();
      final c = _make(b, _FakePush());
      await pump(tester, c, const NotificationPreferencesScreen());
      await tester.pumpAndSettle();
      expect(find.text('Updates'), findsOneWidget);
      final security = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Security'));
      expect(security.onChanged, isNull);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Updates'));
      await tester.pumpAndSettle();
      expect(b.saved?.categories['UPDATE'], isFalse);

      b.offline = true;
      await tester.tap(find.widgetWithText(SwitchListTile, 'Updates'));
      await tester.pumpAndSettle();
      expect(find.text('Could not save. Check your connection and try again.'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Updates')).value, isFalse);
    });
  });
}
