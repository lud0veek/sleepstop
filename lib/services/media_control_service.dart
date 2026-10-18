import 'dart:async';
import 'package:flutter/services.dart';

class ActiveMediaInfo {
  final String? appName;
  final String? packageName;
  final String? mediaTitle;
  final String? mediaArtist;

  const ActiveMediaInfo({
    this.appName,
    this.packageName,
    this.mediaTitle,
    this.mediaArtist,
  });

  bool get hasData =>
      (appName != null && appName!.isNotEmpty) ||
      (mediaTitle != null && mediaTitle!.isNotEmpty);
}

class InstalledAppEntry {
  final String packageName;
  final String appName;
  final bool isMediaCandidate;

  const InstalledAppEntry({
    required this.packageName,
    required this.appName,
    required this.isMediaCandidate,
  });
}

class MediaControlService {
  static const MethodChannel _channel = MethodChannel(
    'com.sleepstop/media_control',
  );

  int? _capturedOriginalVolume;
  Timer? _fadeTimer;
  Completer<bool>? _fadeCompleter;

  int? get capturedOriginalVolume => _capturedOriginalVolume;

  void setNativeCallbacks({
    required void Function() onQuickTileToggle,
    required void Function() onStillAwake,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onQuickTileToggle':
          onQuickTileToggle();
        case 'onStillAwake':
          onStillAwake();
      }
    });
  }

  // ---- Night veil (black overlay at minimum brightness) ------------------

  Future<bool> canDrawOverlays() async {
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openOverlayPermissionSettings() async {
    try {
      await _channel.invokeMethod<bool>('openOverlayPermissionSettings');
    } catch (_) {}
  }

  Future<bool> showNightOverlay({
    required String title,
    required String hint,
    required String countdown,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('showNightOverlay', {
            'title': title,
            'hint': hint,
            'countdown': countdown,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateNightOverlay({
    String? countdown,
    String? title,
    String? hint,
  }) async {
    try {
      await _channel.invokeMethod<bool>('updateNightOverlay', {
        'countdown': countdown,
        'title': title,
        'hint': hint,
      });
    } catch (_) {}
  }

  Future<void> finalizeNightOverlay({
    required String title,
    required String hint,
  }) async {
    try {
      await _channel.invokeMethod<bool>('finalizeNightOverlay', {
        'title': title,
        'hint': hint,
      });
    } catch (_) {}
  }

  Future<void> hideNightOverlay() async {
    try {
      await _channel.invokeMethod<bool>('hideNightOverlay');
    } catch (_) {}
  }

  Future<void> updateQuickTileState({
    required bool isActive,
    required String subtitle,
  }) async {
    try {
      await _channel.invokeMethod<bool>('updateQuickTileState', {
        'isActive': isActive,
        'subtitle': subtitle,
      });
    } catch (_) {}
  }

  Future<bool> consumeQuickTileLaunchTrigger() async {
    try {
      final res = await _channel.invokeMethod<bool>(
        'consumeQuickTileLaunchTrigger',
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String> requestAddQuickSettingsTile() async {
    try {
      final res = await _channel.invokeMethod<String>(
        'requestAddQuickSettingsTile',
      );
      return res ?? 'MANUAL_REQUIRED';
    } catch (_) {
      return 'MANUAL_REQUIRED';
    }
  }

  Future<bool> pauseMedia() async {
    try {
      final res = await _channel.invokeMethod<bool>('pauseMedia');
      return res ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Resumes playback after a false-positive pause ("still awake").
  Future<bool> resumeMedia() async {
    try {
      final res = await _channel.invokeMethod<bool>('resumeMedia');
      return res ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rewindMedia() async {
    try {
      final res = await _channel.invokeMethod<bool>('rewindMedia');
      return res ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<int> getCurrentVolume() async {
    try {
      final vol = await _channel.invokeMethod<int>('getCurrentVolume');
      return vol ?? 8;
    } catch (_) {
      return 8;
    }
  }

  Future<int> getMaxVolume() async {
    try {
      final maxVol = await _channel.invokeMethod<int>('getMaxVolume');
      return (maxVol != null && maxVol > 0) ? maxVol : 15;
    } catch (_) {
      return 15;
    }
  }

  Future<int> setVolume(int index) async {
    try {
      final clamped = index < 0 ? 0 : index;
      final res = await _channel.invokeMethod<int>('setVolume', {
        'index': clamped,
      });
      return res ?? clamped;
    } catch (_) {
      return index;
    }
  }

  Future<bool> isMusicActive() async {
    try {
      final active = await _channel.invokeMethod<bool>('isMusicActive');
      return active ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<ActiveMediaInfo> getActiveMediaInfo() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getActiveMediaInfo',
      );
      if (raw == null) return const ActiveMediaInfo();
      return ActiveMediaInfo(
        appName: raw['appName'] as String?,
        packageName: raw['packageName'] as String?,
        mediaTitle: raw['mediaTitle'] as String?,
        mediaArtist: raw['mediaArtist'] as String?,
      );
    } catch (_) {
      return const ActiveMediaInfo();
    }
  }

  Future<bool> isNotificationListenerEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>(
        'isNotificationListenerEnabled',
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openNotificationListenerSettings() async {
    try {
      await _channel.invokeMethod<bool>('openNotificationListenerSettings');
    } catch (_) {}
  }

  Future<List<InstalledAppEntry>> getInstalledApps() async {
    try {
      final rawList = await _channel.invokeListMethod<dynamic>(
        'getInstalledApps',
      );
      if (rawList == null) return const [];
      return rawList.whereType<Map>().map((m) {
        return InstalledAppEntry(
          packageName: (m['packageName'] ?? '').toString(),
          appName: (m['appName'] ?? '').toString(),
          isMediaCandidate: m['isMediaCandidate'] == true,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> closeTargetApps({
    required List<String> packages,
    required bool goHome,
  }) async {
    try {
      final res = await _channel.invokeListMethod<String>('closeTargetApps', {
        'packages': packages,
        'goHome': goHome,
      });
      return res ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> startVolumeFadeOut({
    required int durationSeconds,
    required void Function(
      int remainingSeconds,
      int currentVolume,
      int originalVolume,
      int maxVolume,
    )
    onProgress,
  }) async {
    await cancelFadeAndRestoreVolume();

    final startVolume = await getCurrentVolume();
    final maxVolume = await getMaxVolume();
    _capturedOriginalVolume = startVolume > 0
        ? startVolume
        : (maxVolume * 0.45).round().clamp(1, maxVolume);

    final effectiveStartVol = startVolume > 0
        ? startVolume
        : _capturedOriginalVolume!;
    final totalSeconds = durationSeconds.clamp(1, 600);
    int elapsedSeconds = 0;

    final completer = Completer<bool>();
    _fadeCompleter = completer;

    onProgress(
      totalSeconds,
      effectiveStartVol,
      _capturedOriginalVolume!,
      maxVolume,
    );

    _fadeTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      elapsedSeconds++;
      final remaining = (totalSeconds - elapsedSeconds).clamp(0, totalSeconds);
      final ratio = remaining / totalSeconds;
      final targetVolume = (effectiveStartVol * ratio).floor().clamp(
        0,
        maxVolume,
      );

      await setVolume(targetVolume);
      onProgress(
        remaining,
        targetVolume,
        _capturedOriginalVolume ?? effectiveStartVol,
        maxVolume,
      );

      if (remaining <= 0) {
        timer.cancel();
        _fadeTimer = null;
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    return completer.future;
  }

  Future<void> cancelFadeAndRestoreVolume() async {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    if (_fadeCompleter != null && !_fadeCompleter!.isCompleted) {
      _fadeCompleter!.complete(false);
    }
    _fadeCompleter = null;

    if (_capturedOriginalVolume != null) {
      final restoreTo = _capturedOriginalVolume!;
      _capturedOriginalVolume = null;
      await setVolume(restoreTo);
    }
  }

  Future<void> pauseAndRestoreVolumeAfterDelay({
    bool rewindBeforePause = false,
  }) async {
    _fadeTimer?.cancel();
    _fadeTimer = null;

    final volumeToRestore =
        _capturedOriginalVolume ?? await getCurrentVolume();

    await setVolume(0);

    if (rewindBeforePause) {
      await rewindMedia();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    await pauseMedia();

    await Future<void>.delayed(const Duration(milliseconds: 1500));

    if (volumeToRestore > 0) {
      await setVolume(volumeToRestore);
    }
    _capturedOriginalVolume = null;
  }

  void dispose() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
  }
}
