import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_stop/models/sleep_settings.dart';
import 'package:sleep_stop/sleep_actions/actions/webhook_action.dart';
import 'package:sleep_stop/sleep_actions/sleep_action.dart';
import 'package:sleep_stop/sleep_actions/sleep_event_bus.dart';

class _Call {
  final Uri url;
  final Map<String, String> headers;
  final List<int> body;
  _Call(this.url, this.headers, this.body);
}

void main() {
  final ts = DateTime.utc(2026, 10, 19, 21, 47, 3);

  SleepActionContext ctx(String url) => SleepActionContext(
    event: SleepDetectedEvent(timestamp: ts, mode: DetectionMode.watchBle),
    settings: SleepSettings(
      sleepActions: SleepActionsSettings(
        enabled: true,
        webhook: WebhookActionSettings(enabled: true, url: url),
      ),
    ),
  );

  group('WebhookUrlValidator', () {
    test('accepts https, rejects http, empty and garbage', () {
      expect(WebhookUrlValidator.validate('https://ha.local/api/webhook/x'), isNull);
      expect(WebhookUrlValidator.validate('  https://example.com '), isNull);
      expect(WebhookUrlValidator.validate('http://ha.local/hook'), 'not_https');
      expect(WebhookUrlValidator.validate(''), 'empty');
      expect(WebhookUrlValidator.validate('not a url'), 'invalid');
      expect(WebhookUrlValidator.validate('ftp://x.y/z'), 'not_https');
    });
  });

  group('WebhookAction', () {
    test('payload is the minimal JSON with an ISO 8601 UTC timestamp', () {
      final body = utf8.decode(WebhookAction.buildBody(ts));
      expect(
        jsonDecode(body),
        {'event': 'sleep_detected', 'timestamp': '2026-10-19T21:47:03.000Z'},
      );
    });

    test('HMAC-SHA256 signature matches the RFC test vector', () {
      // HMAC_SHA256("key", "The quick brown fox jumps over the lazy dog")
      final sig = WebhookAction.sign(
        'key',
        utf8.encode('The quick brown fox jumps over the lazy dog'),
      );
      expect(
        sig,
        'sha256=f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8',
      );
    });

    test('POSTs JSON with the signature header when a secret is stored', () async {
      final calls = <_Call>[];
      final action = WebhookAction(
        secretStore: MemoryWebhookSecretStore('s3cret'),
        sender: (u, h, b) async {
          calls.add(_Call(u, h, b));
          return 200;
        },
      );
      await action.execute(ctx('https://ha.local/api/webhook/sleep'));
      expect(calls, hasLength(1));
      final c = calls.single;
      expect(c.url.toString(), 'https://ha.local/api/webhook/sleep');
      expect(c.headers['Content-Type'], 'application/json');
      expect(
        c.headers['X-SleepStop-Signature'],
        WebhookAction.sign('s3cret', WebhookAction.buildBody(ts)),
      );
      expect(utf8.decode(c.body), contains('"event":"sleep_detected"'));
    });

    test('no secret = no signature header', () async {
      Map<String, String>? seen;
      final action = WebhookAction(
        secretStore: MemoryWebhookSecretStore(),
        sender: (u, h, b) async {
          seen = h;
          return 204;
        },
      );
      await action.execute(ctx('https://example.com/h'));
      expect(seen!.containsKey('X-SleepStop-Signature'), isFalse);
    });

    test('refuses http:// without sending anything', () async {
      var sent = 0;
      final action = WebhookAction(
        secretStore: MemoryWebhookSecretStore(),
        sender: (u, h, b) async {
          sent++;
          return 200;
        },
      );
      await expectLater(
        action.execute(ctx('http://example.com/h')),
        throwsA(isA<WebhookException>()),
      );
      expect(sent, 0);
      expect(action.isEnabled(ctx('http://example.com/h').settings), isFalse);
      expect(action.isEnabled(ctx('https://example.com/h').settings), isTrue);
    });

    test('retries once on a network error, then succeeds', () async {
      var attempts = 0;
      final action = WebhookAction(
        secretStore: MemoryWebhookSecretStore(),
        sender: (u, h, b) async {
          attempts++;
          if (attempts == 1) throw Exception('connection refused');
          return 200;
        },
      );
      await action.execute(ctx('https://example.com/h'));
      expect(attempts, 2);
    });

    test('retries once on 5xx, never more, and fails cleanly', () async {
      var attempts = 0;
      final action = WebhookAction(
        secretStore: MemoryWebhookSecretStore(),
        sender: (u, h, b) async {
          attempts++;
          return 503;
        },
      );
      await expectLater(
        action.execute(ctx('https://example.com/h')),
        throwsA(
          isA<WebhookException>().having((e) => e.message, 'message', 'HTTP 503'),
        ),
      );
      expect(attempts, 2);
    });

    test('does not retry on 4xx', () async {
      var attempts = 0;
      final action = WebhookAction(
        secretStore: MemoryWebhookSecretStore(),
        sender: (u, h, b) async {
          attempts++;
          return 401;
        },
      );
      await expectLater(
        action.execute(ctx('https://example.com/h')),
        throwsA(isA<WebhookException>()),
      );
      expect(attempts, 1);
    });

    test('error messages never contain the URL or the secret', () async {
      final action = WebhookAction(
        secretStore: MemoryWebhookSecretStore('topsecret'),
        sender: (u, h, b) async => 500,
      );
      try {
        await action.execute(ctx('https://private.host/secret-path'));
        fail('should throw');
      } catch (e) {
        expect(e.toString(), isNot(contains('private.host')));
        expect(e.toString(), isNot(contains('topsecret')));
      }
    });
  });
}
