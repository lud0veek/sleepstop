import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_settings.dart';

/// Zero-PII, GDPR-compliant anonymous usage telemetry hosted in Belgium
/// (Google Cloud europe-west1 — Saint-Ghislain, Belgium).
///
/// Strictly complies with EU Regulation 2016/679 (GDPR) and the Belgian Law
/// of 30 July 2018 (Autorité de protection des données / GBA):
/// - Zero biometric / heart-rate data ever transmitted.
/// - Zero personal identifiers, emails, names, or Advertising IDs (GAID).
/// - Zero media/book/video titles transmitted.
/// - Immediate opt-out toggle available in the app settings & Privacy sheet.
class TelemetryService {
  TelemetryService._();

  static final TelemetryService instance = TelemetryService._();

  static const String _projectId = 'sleepstop-eu';
  static const String _baseDocPath =
      'projects/$_projectId/databases/(default)/documents';
  static const String _commitEndpoint =
      'https://firestore.googleapis.com/v1/$_baseDocPath:commit';

  static const String _installCountedKey = 'sleepstop_telemetry_install_v1';
  static const String _lastActiveDayKey = 'sleepstop_telemetry_active_day_v1';
  static const String _lastLangKey = 'sleepstop_telemetry_lang_v1';

  String _todayString() {
    final now = DateTime.now().toUtc();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _sanitizeLang(String lang) {
    return switch (lang.toLowerCase()) {
      'nl' => 'nl',
      'de' => 'de',
      'es' => 'es',
      _ => 'fr',
    };
  }

  String _sanitizeMediaAppCategory(String? rawApp) {
    if (rawApp == null || rawApp.trim().isEmpty) return 'Other';
    final lower = rawApp.toLowerCase();
    if (lower.contains('audible')) return 'Audible';
    if (lower.contains('youtube')) return 'YouTube';
    if (lower.contains('spotify')) return 'Spotify';
    if (lower.contains('netflix')) return 'Netflix';
    if (lower.contains('twitch')) return 'Twitch';
    return 'Other';
  }

  /// Records anonymous first-install and daily-active-user (DAU) counters.
  Future<void> recordAppOpen({
    required bool enabled,
    required String languageCode,
  }) async {
    if (!enabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final installCounted = prefs.getBool(_installCountedKey) ?? false;
      final lastActiveDay = prefs.getString(_lastActiveDayKey);
      final today = _todayString();
      final safeLang = _sanitizeLang(languageCode);

      final globalTransforms = <Map<String, dynamic>>[];
      final dailyTransforms = <Map<String, dynamic>>[];

      if (!installCounted) {
        globalTransforms.add({
          'fieldPath': 'totalInstalls',
          'increment': {'integerValue': '1'},
        });
        globalTransforms.add({
          'fieldPath': 'lang_$safeLang',
          'increment': {'integerValue': '1'},
        });
        await prefs.setBool(_installCountedKey, true);
        await prefs.setString(_lastLangKey, safeLang);
      }

      if (lastActiveDay != today) {
        dailyTransforms.add({
          'fieldPath': 'activeInstalls',
          'increment': {'integerValue': '1'},
        });
        await prefs.setString(_lastActiveDayKey, today);
      }

      if (globalTransforms.isEmpty && dailyTransforms.isEmpty) {
        return;
      }

      globalTransforms.add({
        'fieldPath': 'lastUpdatedAt',
        'setToServerValue': 'REQUEST_TIME',
      });

      final writes = <Map<String, dynamic>>[
        {
          'transform': {
            'document': '$_baseDocPath/stats/global',
            'fieldTransforms': globalTransforms,
          },
        },
        if (dailyTransforms.isNotEmpty)
          {
            'transform': {
              'document': '$_baseDocPath/daily/$today',
              'fieldTransforms': dailyTransforms,
            },
          },
      ];

      await _postCommit(writes);
    } catch (_) {
      // Silent fail — telemetry must never disrupt user experience
    }
  }

  /// Updates anonymous language distribution if the user switches UI language.
  Future<void> recordLanguageSwitch({
    required bool enabled,
    required String newLanguageCode,
  }) async {
    if (!enabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final prevLang = prefs.getString(_lastLangKey);
      final nextLang = _sanitizeLang(newLanguageCode);
      if (prevLang == nextLang) return;
      await prefs.setString(_lastLangKey, nextLang);

      final transforms = <Map<String, dynamic>>[
        {
          'fieldPath': 'lang_$nextLang',
          'increment': {'integerValue': '1'},
        },
        if (prevLang != null && prevLang.isNotEmpty)
          {
            'fieldPath': 'lang_$prevLang',
            'increment': {'integerValue': '-1'},
          },
        {
          'fieldPath': 'lastUpdatedAt',
          'setToServerValue': 'REQUEST_TIME',
        },
      ];

      await _postCommit([
        {
          'transform': {
            'document': '$_baseDocPath/stats/global',
            'fieldTransforms': transforms,
          },
        },
      ]);
    } catch (_) {}
  }

  /// Records an anonymous sleep session start (mode + language).
  Future<void> recordSessionStarted({
    required bool enabled,
    required DetectionMode mode,
    required String languageCode,
  }) async {
    if (!enabled) return;
    final today = _todayString();
    final safeLang = _sanitizeLang(languageCode);
    final modeField = mode == DetectionMode.watchBle
        ? 'watchModeSessions'
        : 'phoneModeSessions';
    final modeName = mode == DetectionMode.watchBle
        ? 'watch_ble'
        : 'phone_shake';
    final eventId = 'evt_${DateTime.now().millisecondsSinceEpoch}';

    final writes = <Map<String, dynamic>>[
      {
        'transform': {
          'document': '$_baseDocPath/stats/global',
          'fieldTransforms': [
            {
              'fieldPath': 'totalSessionsStarted',
              'increment': {'integerValue': '1'},
            },
            {
              'fieldPath': modeField,
              'increment': {'integerValue': '1'},
            },
            {
              'fieldPath': 'lastUpdatedAt',
              'setToServerValue': 'REQUEST_TIME',
            },
          ],
        },
      },
      {
        'transform': {
          'document': '$_baseDocPath/daily/$today',
          'fieldTransforms': [
            {
              'fieldPath': 'sessionsStarted',
              'increment': {'integerValue': '1'},
            },
          ],
        },
      },
      {
        'update': {
          'name': '$_baseDocPath/events/$eventId',
          'fields': {
            'type': {'stringValue': 'session_start'},
            'mode': {'stringValue': modeName},
            'lang': {'stringValue': safeLang},
            'createdAt': {
              'stringValue': DateTime.now().toUtc().toIso8601String(),
            },
          },
        },
      },
    ];

    await _postCommit(writes);
  }

  /// Records an anonymous sleep onset detection event (duration + generic app category).
  Future<void> recordSleepDetected({
    required bool enabled,
    required DetectionMode mode,
    required String languageCode,
    required int listeningMinutes,
    String? mediaAppName,
  }) async {
    if (!enabled) return;
    final today = _todayString();
    final safeLang = _sanitizeLang(languageCode);
    final appCat = _sanitizeMediaAppCategory(mediaAppName);
    final modeName = mode == DetectionMode.watchBle
        ? 'watch_ble'
        : 'phone_shake';
    final safeMins = listeningMinutes.clamp(1, 720);
    final eventId = 'evt_${DateTime.now().millisecondsSinceEpoch}';

    final writes = <Map<String, dynamic>>[
      {
        'transform': {
          'document': '$_baseDocPath/stats/global',
          'fieldTransforms': [
            {
              'fieldPath': 'totalSleepDetected',
              'increment': {'integerValue': '1'},
            },
            {
              'fieldPath': 'totalListeningMinutes',
              'increment': {'integerValue': '$safeMins'},
            },
            {
              'fieldPath': 'app_$appCat',
              'increment': {'integerValue': '1'},
            },
            {
              'fieldPath': 'lastUpdatedAt',
              'setToServerValue': 'REQUEST_TIME',
            },
          ],
        },
      },
      {
        'transform': {
          'document': '$_baseDocPath/daily/$today',
          'fieldTransforms': [
            {
              'fieldPath': 'sleepDetected',
              'increment': {'integerValue': '1'},
            },
          ],
        },
      },
      {
        'update': {
          'name': '$_baseDocPath/events/$eventId',
          'fields': {
            'type': {'stringValue': 'sleep_detected'},
            'mode': {'stringValue': modeName},
            'lang': {'stringValue': safeLang},
            'mediaApp': {'stringValue': appCat},
            'durationMin': {'integerValue': '$safeMins'},
            'createdAt': {
              'stringValue': DateTime.now().toUtc().toIso8601String(),
            },
          },
        },
      },
    ];

    await _postCommit(writes);
  }

  /// Records an anonymous Pro unlock or VIP code activation.
  Future<void> recordProUnlocked({
    required bool enabled,
    required String languageCode,
    required bool isVipCode,
  }) async {
    if (!enabled) return;
    final safeLang = _sanitizeLang(languageCode);
    final eventId = 'evt_${DateTime.now().millisecondsSinceEpoch}';

    final writes = <Map<String, dynamic>>[
      {
        'transform': {
          'document': '$_baseDocPath/stats/global',
          'fieldTransforms': [
            {
              'fieldPath': isVipCode ? 'vipRedeemed' : 'proUnlocks',
              'increment': {'integerValue': '1'},
            },
            {
              'fieldPath': 'lastUpdatedAt',
              'setToServerValue': 'REQUEST_TIME',
            },
          ],
        },
      },
      {
        'update': {
          'name': '$_baseDocPath/events/$eventId',
          'fields': {
            'type': {
              'stringValue': isVipCode ? 'vip_redeemed' : 'pro_unlock',
            },
            'mode': {'stringValue': 'none'},
            'lang': {'stringValue': safeLang},
            'createdAt': {
              'stringValue': DateTime.now().toUtc().toIso8601String(),
            },
          },
        },
      },
    ];

    await _postCommit(writes);
  }

  Future<void> _postCommit(List<Map<String, dynamic>> writes) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client.postUrl(Uri.parse(_commitEndpoint));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final payload = jsonEncode({'writes': writes});
      req.add(utf8.encode(payload));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      await resp.drain<void>();
    } catch (_) {
      // Ignore network errors (offline mode or test environment)
    } finally {
      client.close();
    }
  }
}
