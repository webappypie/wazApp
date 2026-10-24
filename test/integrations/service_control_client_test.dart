import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:wazapp/integrations/wapcentral/service_control_client.dart';
import 'package:wazapp/integrations/wapcentral/wapcentral_config.dart';

const _key = 'wap_key_TESTONLY_not_a_real_key_0123456789';

http.Response json200(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

ServiceControlClient clientFor(http.Client c, {WapCentralConfig? config}) =>
    ServiceControlClient(config: config ?? const WapCentralConfig(), httpClient: c);

void main() {
  group('configuration', () {
    test('URL and headers follow the guide exactly; the key is attached only when configured', () {
      const open = WapCentralConfig();
      expect(open.serviceStatusUri.toString(),
          'https://wapcentral.webappypie.com/api/platform/v1/apps/app_1792836068231/service-status');
      expect(open.headers, {'X-App-Id': 'app_1792836068231', 'Accept': 'application/json'});
      expect(open.headers.containsKey('X-App-Key'), isFalse);

      const keyed = WapCentralConfig(appKey: _key);
      expect(keyed.headers['X-App-Key'], _key);
      expect(keyed.hasKey, isTrue);
    });

    test('toString never reveals the key', () {
      expect(const WapCentralConfig(appKey: _key).toString(), isNot(contains(_key)));
      expect(const WapCentralConfig(appKey: _key).toString(), contains('<redacted>'));
    });

    test('no key is compiled in by default (comes only from --dart-define)', () {
      expect(WapCentralConfig.fromEnvironment().appKey, isEmpty);
      expect(const WapCentralConfig().timeout, const Duration(seconds: 5));
    });
  });

  group('parsing the documented response', () {
    test('enabled service (exact payload shape observed live: only enabled + updatedAt{_seconds})', () async {
      final c = clientFor(MockClient((_) async => json200({
            'success': true,
            'appId': 'app_1792836068231',
            'service': 'service_control',
            'version': 'v1',
            'data': {
              'enabled': true,
              'updatedAt': {'_seconds': 1792837913, '_nanoseconds': 930000000},
            },
            'timestamp': '2026-10-24T23:15:03.329Z',
          })));
      final s = await c.fetch();
      expect(s.enabled, isTrue);
      expect(s.source, StatusSource.server);
    });

    test('disabled service uses the configured title, message, button and URL', () async {
      final c = clientFor(MockClient((_) async => json200({
            'success': true,
            'data': {
              'enabled': false,
              'title': 'Scheduled maintenance',
              'message': 'Back soon.',
              'buttonText': 'Status page',
              'destinationUrl': 'https://example.com/status',
              'updatedAt': '2026-10-24T10:32:29.602Z',
            },
          })));
      final s = await c.fetch();
      expect(s.enabled, isFalse);
      expect(s.title, 'Scheduled maintenance');
      expect(s.message, 'Back soon.');
      expect(s.buttonText, 'Status page');
      expect(s.safeDestination.toString(), 'https://example.com/status');
    });

    test('a disabled service without text fields uses the guide defaults', () async {
      final c = clientFor(MockClient((_) async => json200({'success': true, 'data': {'enabled': false}})));
      final s = await c.fetch();
      expect(s.enabled, isFalse);
      expect(s.title, 'Service Notice');
      expect(s.message, 'Service is currently unavailable.');
      expect(s.buttonText, 'Learn More');
      expect(s.destinationUrl, 'https://webappypie.com');
    });

    test('wrongly typed or blank fields fall back to defaults; non-bool "enabled" means enabled', () async {
      final c = clientFor(MockClient((_) async => json200({
            'success': true,
            'data': {'enabled': 'no', 'title': 7, 'message': '   ', 'buttonText': null},
          })));
      final s = await c.fetch();
      expect(s.enabled, isTrue);
      expect(s.title, 'Service Notice');
      expect(s.message, 'Service is currently unavailable.');
      expect(s.buttonText, 'Learn More');
    });

    test('unsafe destination URLs are never offered (only http/https links)', () {
      for (final bad in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'intent://scan/#Intent;scheme=zxing;end',
        'market://details?id=x',
        'tel:+100',
        'not a url',
        'https://',
      ]) {
        expect(ServiceStatus.fromData({'enabled': false, 'destinationUrl': bad}).safeDestination, isNull, reason: bad);
      }
      expect(ServiceStatus.fromData({'enabled': false, 'destinationUrl': 'http://example.com/x'}).safeDestination, isNotNull);
      // A blank value is not unsafe, it is simply missing: the guide's default link is used.
      expect(ServiceStatus.fromData({'enabled': false, 'destinationUrl': ''}).safeDestination.toString(), 'https://webappypie.com');
    });
  });

  group('fails open (guide section 9, rules 3 and 4)', () {
    Future<void> expectOpen(http.Client client, String reason) async {
      final s = await clientFor(client).fetch();
      expect(s.enabled, isTrue, reason: reason);
      expect(s.source, StatusSource.failOpen, reason: reason);
      expect(s.failureReason, reason);
    }

    test('HTTP 5xx, 4xx and 3xx', () async {
      for (final code in [500, 502, 503, 400, 403, 404, 429, 301]) {
        await expectOpen(MockClient((_) async => http.Response('x', code)), 'http $code');
      }
    });

    test('invalid JSON / wrong shape / success=false / missing data', () async {
      await expectOpen(MockClient((_) async => http.Response('<html>', 200)), 'invalid json');
      await expectOpen(MockClient((_) async => http.Response('[1,2]', 200)), 'unexpected body');
      await expectOpen(MockClient((_) async => json200({'success': false, 'data': {'enabled': false}})), 'unexpected body');
      await expectOpen(MockClient((_) async => json200({'success': true})), 'missing data');
      await expectOpen(MockClient((_) async => json200({'success': true, 'data': 'x'})), 'missing data');
    });

    test('offline / DNS / TLS failures', () async {
      await expectOpen(MockClient((_) async => throw const SocketException('offline')), 'SocketException');
      await expectOpen(MockClient((_) async => throw http.ClientException('dns')), 'network error');
      await expectOpen(MockClient((_) async => throw const HandshakeException('tls')), 'HandshakeException');
    });

    test('timeout after the configured time', () async {
      final slow = MockClient((_) => Completer<http.Response>().future); // never answers
      final c = ServiceControlClient(
        config: const WapCentralConfig(timeout: Duration(milliseconds: 50)),
        httpClient: slow,
      );
      final s = await c.fetch();
      expect(s.enabled, isTrue);
      expect(s.failureReason, 'timeout');
    });
  });

  group('request and logging hygiene', () {
    test('sends exactly one GET to the documented URL with the documented headers', () async {
      http.BaseRequest? seen;
      final c = clientFor(
        MockClient((r) async {
          seen = r;
          return json200({'success': true, 'data': {'enabled': true}});
        }),
        config: const WapCentralConfig(appKey: _key),
      );
      await c.fetch();
      expect(seen!.method, 'GET');
      expect(seen!.url.toString(), 'https://wapcentral.webappypie.com/api/platform/v1/apps/app_1792836068231/service-status');
      expect(seen!.url.hasQuery, isFalse, reason: 'nothing is appended to the URL');
      expect(seen!.headers['X-App-Id'], 'app_1792836068231');
      expect(seen!.headers['X-App-Key'], _key);
      expect(seen!.headers['Accept'], 'application/json');
      expect(seen!.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
    });

    test('the key never reaches the logs, even when requests fail', () async {
      final records = <LogRecord>[];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);

      final failing = clientFor(
        MockClient((_) async => throw Exception('boom with $_key inside')),
        config: const WapCentralConfig(appKey: _key),
      );
      await failing.fetch();
      await clientFor(MockClient((_) async => http.Response('nope $_key', 500)), config: const WapCentralConfig(appKey: _key))
          .fetch();

      expect(records, isNotEmpty, reason: 'failures are logged as warnings');
      for (final r in records) {
        expect('${r.message} ${r.error} ${r.stackTrace}', isNot(contains(_key)));
      }
    });
  });
}
