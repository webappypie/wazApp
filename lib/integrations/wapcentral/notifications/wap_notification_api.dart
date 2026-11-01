import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wap_notifications_sdk/wap_notifications.dart';
// The SDK accepts a custom API service via WapNotifications.initialize but
// does not export the base type.
// ignore: implementation_imports
import 'package:wap_notifications_sdk/src/service/notification_api_service.dart';

/// Thrown when the WAPCentral feed cannot be fetched (offline, timeout,
/// HTTP error, malformed body). Lets the UI show an honest error/offline
/// state instead of an empty list.
class NotificationsUnavailableException implements Exception {
  final String reason;
  const NotificationsUnavailableException(this.reason);
  @override
  String toString() => 'NotificationsUnavailableException: $reason';
}

/// A notification category WAPCentral reports as active for this app
/// (`/notifications/config` → `activeCategories`).
class FeedCategory {
  final String code;
  final String name;
  const FeedCategory(this.code, this.name);
}

/// ShotNest adapter over the SDK's API service that matches the **live**
/// WAPCentral response contract (verified 17 Oct 2026):
///
/// * `GET /notifications` → `{data: {items: [...], unreadCount, total, page}}`.
///   SDK 0.1.0 only reads `data` as a List, so it always returned `[]`.
/// * `GET /notifications/config` → `{data: {notificationsEnabled,
///   globalNotificationsOff, appKillSwitchActive, activeCategories}}`.
///   SDK 0.1.0 reads `enabled`/`appKillSwitch`, so the app kill switch was
///   ignored.
/// * The SDK converts every failure into an empty result; this adapter throws
///   [NotificationsUnavailableException] for feed failures instead.
class WapNotificationApi extends NotificationApiService {
  WapNotificationApi({
    required super.options,
    super.httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _client = httpClient ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Whether the last config fetch reached the server.
  bool lastConfigFromServer = false;

  /// Enabled categories from the last successful config fetch, in server
  /// order. Empty until the config has been fetched.
  List<FeedCategory> categories = const [];

  /// Feed pages fetched per refresh (each [pageSize] items). WAPCentral pages
  /// with `page`/`limit` and reports `total`.
  static const pageSize = 50;
  static const maxPages = 4;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-App-Id': options.appId,
        'X-App-Key': options.appKey,
      };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${options.baseUrl}/api/platform/v1$path')
          .replace(queryParameters: query);

  @override
  Future<NotificationConfig> fetchConfig() async {
    try {
      final response = await _client
          .get(_uri('/notifications/config'), headers: _headers)
          .timeout(timeout);
      if (response.statusCode != 200) {
        lastConfigFromServer = false;
        return NotificationConfig.fallback;
      }
      final data = _dataMap(response.body);
      lastConfigFromServer = true;
      categories = parseCategories(data);
      return parseConfig(data);
    } catch (_) {
      lastConfigFromServer = false;
      return NotificationConfig.fallback;
    }
  }

  /// Maps the live config payload (and the SDK's own field names, if the
  /// server ever sends them) onto [NotificationConfig].
  static NotificationConfig parseConfig(Map<String, dynamic> data) {
    final enabled = (data['notificationsEnabled'] ?? data['enabled']) != false;
    final killed =
        (data['appKillSwitchActive'] ?? data['appKillSwitch']) == true;
    final categories = <String, bool>{};
    final active = data['activeCategories'];
    if (active is List) {
      for (final c in active.whereType<Map>()) {
        final id = c['id']?.toString().toUpperCase();
        if (id != null) categories[id] = c['enabled'] == false;
      }
    }
    return NotificationConfig(
      enabled: enabled,
      globalNotificationsOff: data['globalNotificationsOff'] == true,
      appKillSwitch: killed,
      supportedCategories: categories.keys.toList(),
      categoryKillSwitches: categories,
    );
  }

  /// Enabled categories from the config payload, keeping the server's names.
  static List<FeedCategory> parseCategories(Map<String, dynamic> data) {
    final active = data['activeCategories'];
    if (active is! List) return const [];
    final out = <FeedCategory>[];
    for (final c in active.whereType<Map>()) {
      final code = c['id']?.toString().trim().toUpperCase() ?? '';
      if (code.isEmpty || c['enabled'] == false) continue;
      if (out.any((e) => e.code == code)) continue;
      final name = c['name']?.toString().trim();
      out.add(FeedCategory(code, name == null || name.isEmpty ? code : name));
    }
    return out;
  }

  @override
  Future<List<WapNotification>> fetchBellNotifications({
    String? deviceId,
    String? userId,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    // The SDK asks for its own limit; ShotNest reads every page (up to
    // [maxPages]) so filters and the unread count see the whole feed.
    final out = <WapNotification>[];
    final seen = <String>{};
    for (var page = 1; page <= maxPages; page++) {
      final body = await _getFeedPage(page,
          deviceId: deviceId, userId: userId, unreadOnly: unreadOnly);
      final result = parseFeedPage(body);
      for (final n in result.items) {
        if (seen.add(n.id)) out.add(n);
      }
      if (result.items.length < pageSize ||
          (result.total != null && page * pageSize >= result.total!)) {
        break;
      }
    }
    return out;
  }

  Future<String> _getFeedPage(int page,
      {String? deviceId, String? userId, bool unreadOnly = false}) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            _uri('/notifications', {
              'limit': '$pageSize',
              'page': '$page',
              'deviceId': ?deviceId,
              'userId': ?userId,
              if (unreadOnly) 'unreadOnly': 'true',
            }),
            headers: _headers,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const NotificationsUnavailableException('timeout');
    } catch (_) {
      throw const NotificationsUnavailableException('network');
    }
    if (response.statusCode != 200) {
      throw NotificationsUnavailableException('http_${response.statusCode}');
    }
    return response.body;
  }

  /// Parses the feed body. Accepts the live shape (`data.items`) and the
  /// shapes SDK 0.1.0 expected (`data` list or top-level `notifications`).
  /// Malformed items are skipped rather than failing the whole feed.
  static List<WapNotification> parseFeed(String body) =>
      parseFeedPage(body).items;

  /// Like [parseFeed], also returning the server's `total` when present.
  ///
  /// The live feed sends the read flag as `read`; the SDK model only reads
  /// `isRead`, so without this mapping every refresh showed all items as
  /// unread. Duplicate ids keep the first occurrence.
  static ({List<WapNotification> items, int? total}) parseFeedPage(
      String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const NotificationsUnavailableException('malformed');
    }
    if (decoded is! Map) {
      throw const NotificationsUnavailableException('malformed');
    }
    final data = decoded['data'];
    final Object? items = data is Map
        ? data['items']
        : data is List
            ? data
            : decoded['notifications'];
    final total = data is Map ? (data['total'] as num?)?.toInt() : null;
    if (items is! List) return (items: const [], total: total);
    final out = <WapNotification>[];
    final seen = <String>{};
    for (final item in items.whereType<Map>()) {
      try {
        final json = Map<String, dynamic>.from(item);
        if (json['isRead'] is! bool && json['read'] is bool) {
          json['isRead'] = json['read'];
        }
        final n = WapNotification.fromJson(json);
        if (n.id.isNotEmpty &&
            (n.title.isNotEmpty || n.message.isNotEmpty) &&
            seen.add(n.id)) {
          out.add(n);
        }
      } catch (_) {
        // Skip a malformed item; keep the rest of the feed.
      }
    }
    return (items: out, total: total);
  }

  @override
  Future<int> fetchUnreadCount({String? deviceId, String? userId}) async {
    try {
      final response = await _client
          .get(
            _uri('/notifications/unread-count', {
              'deviceId': ?deviceId,
              'userId': ?userId,
            }),
            headers: _headers,
          )
          .timeout(timeout);
      if (response.statusCode != 200) return 0;
      return (_dataMap(response.body)['unreadCount'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Map<String, dynamic> _dataMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['data'] is Map) {
      return Map<String, dynamic>.from(decoded['data'] as Map);
    }
    return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
  }
}
