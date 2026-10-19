import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/sleep_settings.dart';
import '../sleep_action.dart';

/// Where the optional HMAC secret lives. Never in the settings JSON.
abstract class WebhookSecretStore {
  Future<String?> read();
  Future<void> write(String secret);
  Future<void> clear();
}

/// Android Keystore-backed storage (EncryptedSharedPreferences under the hood).
class SecureWebhookSecretStore implements WebhookSecretStore {
  static const _key = 'sleepstop_webhook_secret';
  // Default Android backend = AES keys in the Android Keystore.
  static const _storage = FlutterSecureStorage();

  const SecureWebhookSecretStore();

  @override
  Future<String?> read() async {
    try {
      final v = await _storage.read(key: _key);
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String secret) => _storage.write(key: _key, value: secret);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// In-memory store for tests and previews.
class MemoryWebhookSecretStore implements WebhookSecretStore {
  String? _secret;
  MemoryWebhookSecretStore([this._secret]);
  @override
  Future<String?> read() async => _secret;
  @override
  Future<void> write(String secret) async => _secret = secret;
  @override
  Future<void> clear() async => _secret = null;
}

/// Minimal HTTP transport so the action can be tested without sockets.
/// Returns the HTTP status code; throws on network failure.
typedef WebhookSender =
    Future<int> Function(Uri url, Map<String, String> headers, List<int> body);

class WebhookException implements Exception {
  final String message;
  const WebhookException(this.message);
  @override
  String toString() => message;
}

class WebhookUrlValidator {
  /// Returns null when [raw] is an acceptable HTTPS URL, else a short reason
  /// code: `empty`, `invalid`, `not_https`.
  static String? validate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 'empty';
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return 'invalid';
    if (uri.scheme.toLowerCase() != 'https') return 'not_https';
    return null;
  }
}

/// POSTs `{"event":"sleep_detected","timestamp":"<ISO 8601>"}` to the
/// user's HTTPS endpoint, optionally signed with HMAC-SHA256 in
/// `X-SleepStop-Signature: sha256=<hex>`. 10 s timeout, one retry max.
class WebhookAction implements SleepAction {
  static const String actionId = 'webhook';
  static const String signatureHeader = 'X-SleepStop-Signature';
  static const Duration requestTimeout = Duration(seconds: 10);

  final WebhookSecretStore secretStore;
  final WebhookSender _send;

  WebhookAction({required this.secretStore, WebhookSender? sender})
    : _send = sender ?? _defaultSender;

  @override
  String get id => actionId;

  @override
  bool isEnabled(SleepSettings settings) {
    final w = settings.sleepActions.webhook;
    return w.enabled && WebhookUrlValidator.validate(w.url) == null;
  }

  /// Exact body sent for [timestamp] (UTC, ISO 8601). Exposed for tests.
  static List<int> buildBody(DateTime timestamp) => utf8.encode(
    jsonEncode({
      'event': 'sleep_detected',
      'timestamp': timestamp.toUtc().toIso8601String(),
    }),
  );

  /// `sha256=<hex HMAC-SHA256(secret, body)>`.
  static String sign(String secret, List<int> body) {
    final mac = Hmac(sha256, utf8.encode(secret)).convert(body);
    return 'sha256=${mac.toString()}';
  }

  @override
  Future<void> execute(SleepActionContext context) async {
    final raw = context.settings.sleepActions.webhook.url;
    final problem = WebhookUrlValidator.validate(raw);
    if (problem != null) {
      throw WebhookException('url $problem');
    }
    final url = Uri.parse(raw.trim());
    final body = buildBody(context.event.timestamp);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': 'SleepStop/1.0 (Android)',
    };
    final secret = await secretStore.read();
    if (secret != null && secret.isNotEmpty) {
      headers[signatureHeader] = sign(secret, body);
    }

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final status = await _send(url, headers, body).timeout(requestTimeout);
        if (status >= 200 && status < 300) return;
        if (status >= 500) {
          lastError = WebhookException('HTTP $status');
          continue; // one retry on server errors
        }
        throw WebhookException('HTTP $status'); // 4xx: no retry
      } on WebhookException {
        rethrow;
      } catch (e) {
        lastError = e; // network / timeout: one retry
      }
    }
    throw WebhookException(
      lastError is WebhookException
          ? lastError.message
          : 'network error',
    );
  }

  @override
  Future<void> cancel() async {
    // A request in flight finishes or times out by itself; nothing to undo.
  }

  static Future<int> _defaultSender(
    Uri url,
    Map<String, String> headers,
    List<int> body,
  ) async {
    final client = HttpClient()..connectionTimeout = requestTimeout;
    try {
      final req = await client.postUrl(url);
      headers.forEach(req.headers.set);
      req.contentLength = body.length;
      req.add(body);
      final resp = await req.close();
      await resp.drain<void>();
      return resp.statusCode;
    } finally {
      client.close(force: true);
    }
  }
}
