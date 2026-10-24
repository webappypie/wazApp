// lib/integrations/wapcentral/service_control_client.dart
//
// REST client for WAPCentral "Remote App Service Control" (guide section 9).
//
// Contract implemented exactly as documented:
//   GET /api/platform/v1/apps/{appId}/service-status
//   200 + {"success": true, "data": {"enabled": bool, "title"?, "message"?, "buttonText"?, "destinationUrl"?}}
//   - `enabled: false` blocks the app (shown by ServiceGate).
//   - ANY failure (timeout, offline, DNS, HTTP non-200 incl. 5xx, bad JSON, missing/invalid data) FAILS OPEN
//     (enabled: true) so offline users keep full local functionality (guide section 9 rules 3 and 4).
//   - Missing text fields use the guide's documented defaults.
//
// Observed against the live endpoint on 2026-10-25: when the service is enabled `data` contains only
// `enabled` and `updatedAt` (a Firestore-style {_seconds,_nanoseconds} object, not a string), so every
// other field is optional and `updatedAt` is ignored.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../core/logging/app_logger.dart';
import 'wapcentral_config.dart';

enum StatusSource {
  /// Answer received from WAPCentral.
  server,

  /// Request failed or answer was unusable; treated as enabled.
  failOpen,

  /// Nothing has been asked yet.
  initial,
}

@immutable
class ServiceStatus {
  const ServiceStatus({
    required this.enabled,
    this.title = defaultTitle,
    this.message = defaultMessage,
    this.buttonText = defaultButtonText,
    this.destinationUrl = defaultDestinationUrl,
    this.source = StatusSource.server,
    this.failureReason,
  });

  /// Fail-open status: the app keeps working.
  const ServiceStatus.open({this.source = StatusSource.failOpen, this.failureReason})
      : enabled = true,
        title = defaultTitle,
        message = defaultMessage,
        buttonText = defaultButtonText,
        destinationUrl = defaultDestinationUrl;

  // Defaults from the guide's reference implementation (section 9).
  static const defaultTitle = 'Service Notice';
  static const defaultMessage = 'Service is currently unavailable.';
  static const defaultButtonText = 'Learn More';
  static const defaultDestinationUrl = 'https://webappypie.com';

  final bool enabled;
  final String title;
  final String message;
  final String buttonText;
  final String destinationUrl;
  final StatusSource source;

  /// Why the request failed open (for logs/diagnostics only; never shown with secrets).
  final String? failureReason;

  /// The destination as a URI, only if it is a plain web link (http/https). Anything else
  /// (intent:, file:, javascript:, ...) is ignored so a malformed config cannot launch other apps.
  Uri? get safeDestination {
    final uri = Uri.tryParse(destinationUrl.trim());
    if (uri == null || uri.host.isEmpty) return null;
    return (uri.scheme == 'https' || uri.scheme == 'http') ? uri : null;
  }

  /// Parses the `data` object. Unknown / mistyped fields fall back to the documented defaults.
  factory ServiceStatus.fromData(Map<String, dynamic> data) {
    String text(String key, String fallback) {
      final v = data[key];
      return v is String && v.trim().isNotEmpty ? v : fallback;
    }

    final enabled = data['enabled'];
    return ServiceStatus(
      enabled: enabled is bool ? enabled : true,
      title: text('title', defaultTitle),
      message: text('message', defaultMessage),
      buttonText: text('buttonText', defaultButtonText),
      destinationUrl: text('destinationUrl', defaultDestinationUrl),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ServiceStatus &&
      other.enabled == enabled &&
      other.title == title &&
      other.message == message &&
      other.buttonText == buttonText &&
      other.destinationUrl == destinationUrl &&
      other.source == source;

  @override
  int get hashCode => Object.hash(enabled, title, message, buttonText, destinationUrl, source);
}

class ServiceControlClient {
  ServiceControlClient({required this.config, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final WapCentralConfig config;
  final http.Client _http;
  final Logger _log = AppLogger.get('WAPCentral');

  /// Asks WAPCentral whether the service is enabled. Never throws.
  Future<ServiceStatus> fetch() async {
    try {
      final response = await _http.get(config.serviceStatusUri, headers: config.headers).timeout(config.timeout);
      if (response.statusCode != 200) {
        return _failOpen('http ${response.statusCode}');
      }
      final body = json.decode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic> || body['success'] != true) {
        return _failOpen('unexpected body');
      }
      final data = body['data'];
      if (data is! Map<String, dynamic>) return _failOpen('missing data');
      return ServiceStatus.fromData(data);
    } on TimeoutException {
      return _failOpen('timeout');
    } on FormatException {
      return _failOpen('invalid json');
    } on http.ClientException {
      return _failOpen('network error');
    } catch (e) {
      // SocketException/HandshakeException/TLS and anything else: never lock a local-first app.
      return _failOpen(e.runtimeType.toString());
    }
  }

  ServiceStatus _failOpen(String reason) {
    // Reason only: no URL, headers or body, so no key can reach the logs.
    _log.warning('Service status check failed open ($reason)');
    return ServiceStatus.open(failureReason: reason);
  }

  void close() => _http.close();
}
