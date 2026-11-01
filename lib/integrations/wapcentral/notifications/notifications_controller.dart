// lib/integrations/wapcentral/notifications/notifications_controller.dart
//
// WAPCentral notifications (guide section 10): device registration, the in-app feed and read state.
//
//  - Feed and read state live on WAPCentral. Reads are applied immediately in the UI and kept as "pending"
//    until the server confirms them.
//  - FCM token registration happens ONLY while the OS notification permission is granted. The permission
//    screens call [NotificationsController.syncRegistration] after the user grants it; it also runs on start
//    and on resume (so a permission granted in system settings is picked up without prompting again).
//  - No key (build without --dart-define=WAP_APP_KEY) => status [NotificationsStatus.disabled], nothing is sent.
//  - Nothing here blocks the UI or throws; offline keeps the last loaded feed and flags it as out of date.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wap_notifications_sdk/wap_notifications.dart';

import 'notification_backend.dart';
import 'push_gateway.dart';
import 'wap_notification_api.dart';

enum NotificationsStatus { idle, disabled, loading, ready, error }

@immutable
class NotificationsState {
  const NotificationsState({
    this.status = NotificationsStatus.idle,
    this.items = const [],
    this.isRefreshing = false,
    this.isStale = false,
    this.pushRegistered = false,
  });

  final NotificationsStatus status;

  /// Newest first.
  final List<WapNotification> items;
  final bool isRefreshing;

  /// The last refresh failed; [items] is the previously loaded feed.
  final bool isStale;

  /// This device's FCM token was accepted by WAPCentral in this session.
  final bool pushRegistered;

  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<WapNotification>? items,
    bool? isRefreshing,
    bool? isStale,
    bool? pushRegistered,
  }) =>
      NotificationsState(
        status: status ?? this.status,
        items: items ?? this.items,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isStale: isStale ?? this.isStale,
        pushRegistered: pushRegistered ?? this.pushRegistered,
      );
}

final notificationBackendProvider = Provider<NotificationBackend>((ref) => WapNotificationBackend());
final pushGatewayProvider = Provider<PushGateway>((ref) => FirebasePushGateway());

class NotificationsController extends Notifier<NotificationsState> {
  static const _deviceIdKey = 'wap_device_id_v1';
  static const _pendingReadKey = 'wap_pending_read_v1';

  final List<StreamSubscription<dynamic>> _subs = [];
  Set<String> _pendingReads = {};
  String? _registeredToken;
  DateTime? _lastRefresh;
  Future<void>? _starting;
  bool _backendReady = false;
  bool _pushWired = false;

  /// Notifications that arrived while the app was open (e.g. for a snackbar).
  final _arrivals = StreamController<WapNotification>.broadcast();
  Stream<WapNotification> get arrivals => _arrivals.stream;

  /// Id of a notification the user tapped in the system tray; consumers clear it with [consumeOpenRequest].
  final ValueNotifier<String?> openRequests = ValueNotifier(null);

  // Captured in build() so work that finishes after the provider is disposed never touches a dead Ref.
  late NotificationBackend _backend;
  late PushGateway _push;

  @override
  NotificationsState build() {
    _backend = ref.read(notificationBackendProvider);
    _push = ref.read(pushGatewayProvider);
    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _arrivals.close();
      openRequests.dispose();
    });
    return const NotificationsState();
  }

  /// Applies a partial state update unless the provider was disposed meanwhile (async work may outlive it).
  void _patch({
    NotificationsStatus? status,
    List<WapNotification>? items,
    bool? isRefreshing,
    bool? isStale,
    bool? pushRegistered,
  }) {
    if (!ref.mounted) return;
    state = state.copyWith(
      status: status,
      items: items,
      isRefreshing: isRefreshing,
      isStale: isStale,
      pushRegistered: pushRegistered,
    );
  }

  bool get isNotConfigured => !_backend.isConfigured;

  /// Categories WAPCentral reports as active for WazApp.
  List<FeedCategory> get categories => _backend.categories;

  /// Starts the integration. Safe to call repeatedly; never throws and never blocks the UI.
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    if (!_backend.isConfigured) {
      _patch(status: NotificationsStatus.disabled);
      return;
    }
    await _loadPending();
    _patch(status: NotificationsStatus.loading);
    if (!await _ensureBackend()) {
      _patch(status: NotificationsStatus.error);
      return;
    }
    await refresh();
    unawaited(syncRegistration());
  }

  Future<bool> _ensureBackend() async {
    if (_backendReady) return true;
    try {
      await _backend.initialize(deviceId: await _deviceId()).timeout(const Duration(seconds: 12));
      _backendReady = true;
    } catch (e) {
      debugPrint('[Notifications] init failed: ${e.runtimeType}');
    }
    return _backendReady;
  }

  /// Registers this device's FCM token with WAPCentral when the OS notification permission is granted.
  /// Never prompts. Returns whether a token is registered.
  Future<bool> syncRegistration() => _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<bool>? _syncing;

  Future<bool> _sync() async {
    if (!_backend.isConfigured) return false;
    if (!await _ensureBackend()) return false;
    if (_backend.isSuppressed) return false;
    if (!await _push.initialize()) return false;
    if (!await _push.isPermissionGranted()) return false;
    if (!_pushWired) {
      _pushWired = true;
      _subs
        ..add(_push.onTokenRefresh.listen(_register))
        ..add(_push.onForegroundMessage.listen(_onForegroundPush))
        ..add(_push.onMessageOpened.listen(_onPushOpened));
      final initial = await _push.initialMessage();
      if (initial != null) _onPushOpened(initial);
    }
    final token = await _push.token();
    if (token == null) return false;
    return _register(token);
  }

  Future<bool> _register(String token) async {
    if (token == _registeredToken) return true;
    try {
      final ok = await _backend.registerPushToken(token, platform: _platform);
      if (ok) {
        _registeredToken = token;
        _patch(pushRegistered: true);
      }
      // Outcome only; never the token, key or device id.
      debugPrint('[Notifications] push registration accepted: $ok');
      return ok;
    } catch (e) {
      debugPrint('[Notifications] token registration failed: ${e.runtimeType}');
      return false;
    }
  }

  String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Fetches the feed; keeps the last good feed visible when the fetch fails.
  Future<void> refresh() async {
    if (!_backend.isConfigured || state.isRefreshing) return;
    if (!await _ensureBackend()) {
      _patch(status: NotificationsStatus.error, isStale: state.items.isNotEmpty);
      return;
    }
    _patch(isRefreshing: true);
    try {
      final fresh = await _backend.fetch();
      if (_backend.isSuppressed) {
        _patch(items: const [], status: NotificationsStatus.disabled);
      } else {
        _patch(items: _merge(fresh), status: NotificationsStatus.ready, isStale: false);
        unawaited(_retryPendingReads());
      }
      _lastRefresh = DateTime.now();
    } on NotificationsUnavailableException {
      _patch(status: NotificationsStatus.error, isStale: state.items.isNotEmpty);
    } catch (e) {
      debugPrint('[Notifications] refresh failed: ${e.runtimeType}');
      _patch(status: NotificationsStatus.error, isStale: state.items.isNotEmpty);
    } finally {
      _patch(isRefreshing: false);
    }
  }

  /// Called on app resume: re-checks the OS permission (it may have changed in system settings) and refreshes
  /// the feed at most every [minInterval].
  Future<void> onResume({Duration minInterval = const Duration(minutes: 2)}) async {
    if (state.status == NotificationsStatus.idle || state.status == NotificationsStatus.disabled) return;
    unawaited(syncRegistration());
    final last = _lastRefresh;
    if (last != null && DateTime.now().difference(last) < minInterval) return;
    await refresh();
  }

  List<WapNotification> _merge(List<WapNotification> feed) {
    final seen = <String>{};
    final out = <WapNotification>[];
    var pendingChanged = false;
    for (final n in feed) {
      if (n.id.isEmpty || !seen.add(n.id)) continue;
      if (n.isRead) {
        pendingChanged |= _pendingReads.remove(n.id);
        out.add(n);
      } else if (_pendingReads.contains(n.id)) {
        out.add(n.copyWith(isRead: true, readAt: n.readAt ?? DateTime.now()));
      } else {
        out.add(n);
      }
    }
    if (pendingChanged) unawaited(_savePending());
    return _sorted(out);
  }

  // ---- read state ---------------------------------------------------------------------------------------------

  /// Marks one notification read. The badge updates at once; false when WAPCentral did not confirm (retried later).
  Future<bool> markRead(String id) async {
    final index = state.items.indexWhere((n) => n.id == id);
    if (index == -1) return true;
    if (state.items[index].isRead && !_pendingReads.contains(id)) return true;
    if (!state.items[index].isRead) {
      final items = [...state.items]..[index] = state.items[index].copyWith(isRead: true, readAt: DateTime.now());
      _patch(items: items);
    }
    _pendingReads.add(id);
    unawaited(_savePending());
    return _sendRead(id);
  }

  Future<bool> _sendRead(String id) async {
    try {
      final ok = await _backend.markRead(id);
      if (ok && _pendingReads.remove(id)) unawaited(_savePending());
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllRead() async {
    final unread = [for (final n in state.items) if (!n.isRead) n.id];
    if (unread.isEmpty) return true;
    final now = DateTime.now();
    _patch(items: [for (final n in state.items) n.isRead ? n : n.copyWith(isRead: true, readAt: now)]);
    _pendingReads.addAll(unread);
    unawaited(_savePending());
    try {
      return await _backend.markAllRead();
    } catch (_) {
      return false;
    }
  }

  Future<void> _retryPendingReads() async {
    final ids = [for (final id in _pendingReads) if (state.items.any((n) => n.id == id)) id];
    if (ids.length != _pendingReads.length) {
      _pendingReads = ids.toSet();
      unawaited(_savePending());
    }
    for (final id in ids) {
      if (!await _sendRead(id)) break; // offline: next refresh
    }
  }

  // ---- push events --------------------------------------------------------------------------------------------

  void _onForegroundPush(Map<String, dynamic> payload) {
    if (_backend.isSuppressed) return;
    final n = _backend.fromPush(payload);
    if (n.title.isEmpty && n.message.isEmpty) return;
    final isNew = !state.items.any((e) => e.id == n.id);
    if (isNew) {
      _patch(items: _sorted([n, ...state.items]), status: NotificationsStatus.ready);
      if (!_arrivals.isClosed) _arrivals.add(n);
    }
  }

  void _onPushOpened(Map<String, dynamic> payload) {
    final n = _backend.fromPush(payload);
    if (n.id.isNotEmpty && state.items.every((e) => e.id != n.id) && (n.title.isNotEmpty || n.message.isNotEmpty)) {
      _patch(items: _sorted([n, ...state.items]));
    }
    if (n.id.isNotEmpty) {
      unawaited(markRead(n.id));
      openRequests.value = n.id;
    }
    unawaited(refresh());
  }

  void consumeOpenRequest() => openRequests.value = null;

  // ---- preferences --------------------------------------------------------------------------------------------

  Future<NotificationPreferences?> loadPreferences() async {
    if (!_backend.isConfigured || !await _ensureBackend()) return null;
    try {
      return await _backend.getPreferences();
    } catch (_) {
      return null;
    }
  }

  Future<bool> savePreferences(NotificationPreferences preferences) async {
    if (!_backend.isConfigured || !await _ensureBackend()) return false;
    try {
      return await _backend.updatePreferences(preferences);
    } catch (_) {
      return false;
    }
  }

  // ---- links --------------------------------------------------------------------------------------------------

  /// The https link a notification carries, or null. A bare host (the dashboard accepts `webappypie.com`) opens as
  /// https; every other scheme is ignored. WazApp defines no deep-link routes, so in-app links are not followed.
  static Uri? linkFor(WapNotification n) => _https(n.externalUrl) ?? _https(n.deepLink);

  static Uri? imageFor(WapNotification n) => _https(n.imageUrl);

  static final _bareHost = RegExp(
      r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*'
      r'\.[a-z]{2,}(?::\d{1,5})?(?:[/?#]\S*)?$',
      caseSensitive: false);

  static Uri? _https(String? raw) {
    var text = raw?.trim() ?? '';
    if (_bareHost.hasMatch(text)) text = 'https://$text';
    final uri = Uri.tryParse(text);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty ? uri : null;
  }

  // ---- persistence --------------------------------------------------------------------------------------------

  static List<WapNotification> _sorted(List<WapNotification> list) {
    final copy = [...list];
    copy.sort((a, b) {
      final at = a.createdAt, bt = b.createdAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return copy;
  }

  /// A random id generated by the app (not a hardware or advertising identifier); keeps read state across launches.
  Future<String> _deviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_deviceIdKey);
      if (id == null || id.isEmpty) {
        final r = Random.secure();
        id = 'wz_${List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
        await prefs.setString(_deviceIdKey, id);
      }
      return id;
    } catch (_) {
      return 'wz_session_${DateTime.now().microsecondsSinceEpoch}';
    }
  }

  Future<void> _loadPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pendingReads = (prefs.getStringList(_pendingReadKey) ?? []).toSet();
    } catch (_) {}
  }

  Future<void> _savePending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_pendingReadKey, _pendingReads.toList());
    } catch (_) {}
  }
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(NotificationsController.new);
