import 'dart:convert';

enum DetectionMode {
  watchBle,
  phoneFadeShake;

  String get label => switch (this) {
    DetectionMode.watchBle => 'Watch (BLE)',
    DetectionMode.phoneFadeShake => 'Phone (Fade & Shake)',
  };

  String get subtitle => switch (this) {
    DetectionMode.watchBle => 'Smart Adaptive Biometrics (0x180D)',
    DetectionMode.phoneFadeShake => 'Dead Man\'s Switch + Accelerometer',
  };
}

enum BiometricTriggerMode {
  smartAdaptive,
  manualBpm;

  String get label => switch (this) {
    BiometricTriggerMode.smartAdaptive => 'Smart Adaptive (Firstbeat Style)',
    BiometricTriggerMode.manualBpm => 'Manual Fixed BPM',
  };
}

enum AdaptiveSensitivity {
  fast,
  balanced,
  deep;

  String get label => switch (this) {
    AdaptiveSensitivity.fast => 'Fast (Light Sleep N1)',
    AdaptiveSensitivity.balanced => 'Balanced (Recommended)',
    AdaptiveSensitivity.deep => 'Deep (Confirmed N2)',
  };

  String get description => switch (this) {
    AdaptiveSensitivity.fast =>
      'Triggers quickly as soon as HR drops & stabilizes (~3 min)',
    AdaptiveSensitivity.balanced =>
      'Ideal balance of adaptive HR drop + plateau stability (~4 min)',
    AdaptiveSensitivity.deep =>
      'Waits for deeper parasympathetic stabilization (~6 min)',
  };
}

class SleepSettings {
  static const Map<String, String> defaultTargetApps = {
    'com.audible.application': 'Audible',
    'com.google.android.youtube': 'YouTube',
    'com.spotify.music': 'Spotify',
    'com.netflix.mediaclient': 'Netflix',
    'tv.twitch.android.app': 'Twitch',
  };

  final DetectionMode preferredMode;
  final BiometricTriggerMode biometricTriggerMode;
  final AdaptiveSensitivity adaptiveSensitivity;
  final int sleepBpmThreshold;
  final bool useAutoBaseline;
  final double autoBaselineDropPercent;
  final int confirmationDurationMinutes;
  final int checkIntervalMinutes;
  final double shakeSensitivity;
  final bool rewindOnPause;
  final bool closeAppsOnSleep;
  final bool returnToHomeOnSleep;
  final Map<String, String> targetAppsToClose;
  final String? savedWatchId;
  final String? savedWatchName;
  final double? learnedSleepingBpm;
  final String languageCode;
  final bool isProUnlocked;

  static const int totalFreeTrialNights = 5;

  const SleepSettings({
    this.preferredMode = DetectionMode.watchBle,
    this.biometricTriggerMode = BiometricTriggerMode.smartAdaptive,
    this.adaptiveSensitivity = AdaptiveSensitivity.balanced,
    this.sleepBpmThreshold = 55,
    this.useAutoBaseline = true,
    this.autoBaselineDropPercent = 10.0,
    this.confirmationDurationMinutes = 4,
    this.checkIntervalMinutes = 15,
    this.shakeSensitivity = 1.8,
    this.rewindOnPause = false,
    this.closeAppsOnSleep = true,
    this.returnToHomeOnSleep = true,
    this.targetAppsToClose = defaultTargetApps,
    this.savedWatchId,
    this.savedWatchName,
    this.learnedSleepingBpm,
    this.languageCode = 'fr',
    this.isProUnlocked = false,
  });

  SleepSettings copyWith({
    DetectionMode? preferredMode,
    BiometricTriggerMode? biometricTriggerMode,
    AdaptiveSensitivity? adaptiveSensitivity,
    int? sleepBpmThreshold,
    bool? useAutoBaseline,
    double? autoBaselineDropPercent,
    int? confirmationDurationMinutes,
    int? checkIntervalMinutes,
    double? shakeSensitivity,
    bool? rewindOnPause,
    bool? closeAppsOnSleep,
    bool? returnToHomeOnSleep,
    Map<String, String>? targetAppsToClose,
    String? savedWatchId,
    String? savedWatchName,
    bool clearSavedWatch = false,
    double? learnedSleepingBpm,
    String? languageCode,
    bool? isProUnlocked,
  }) {
    return SleepSettings(
      preferredMode: preferredMode ?? this.preferredMode,
      biometricTriggerMode: biometricTriggerMode ?? this.biometricTriggerMode,
      adaptiveSensitivity: adaptiveSensitivity ?? this.adaptiveSensitivity,
      sleepBpmThreshold: sleepBpmThreshold ?? this.sleepBpmThreshold,
      useAutoBaseline: useAutoBaseline ?? this.useAutoBaseline,
      autoBaselineDropPercent:
          autoBaselineDropPercent ?? this.autoBaselineDropPercent,
      confirmationDurationMinutes:
          confirmationDurationMinutes ?? this.confirmationDurationMinutes,
      checkIntervalMinutes: checkIntervalMinutes ?? this.checkIntervalMinutes,
      shakeSensitivity: shakeSensitivity ?? this.shakeSensitivity,
      rewindOnPause: rewindOnPause ?? this.rewindOnPause,
      closeAppsOnSleep: closeAppsOnSleep ?? this.closeAppsOnSleep,
      returnToHomeOnSleep: returnToHomeOnSleep ?? this.returnToHomeOnSleep,
      targetAppsToClose: targetAppsToClose ?? this.targetAppsToClose,
      savedWatchId: clearSavedWatch
          ? null
          : (savedWatchId ?? this.savedWatchId),
      savedWatchName: clearSavedWatch
          ? null
          : (savedWatchName ?? this.savedWatchName),
      learnedSleepingBpm: learnedSleepingBpm ?? this.learnedSleepingBpm,
      languageCode: languageCode ?? this.languageCode,
      isProUnlocked: isProUnlocked ?? this.isProUnlocked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferredMode': preferredMode.name,
      'biometricTriggerMode': biometricTriggerMode.name,
      'adaptiveSensitivity': adaptiveSensitivity.name,
      'sleepBpmThreshold': sleepBpmThreshold,
      'useAutoBaseline': useAutoBaseline,
      'autoBaselineDropPercent': autoBaselineDropPercent,
      'confirmationDurationMinutes': confirmationDurationMinutes,
      'checkIntervalMinutes': checkIntervalMinutes,
      'shakeSensitivity': shakeSensitivity,
      'rewindOnPause': rewindOnPause,
      'closeAppsOnSleep': closeAppsOnSleep,
      'returnToHomeOnSleep': returnToHomeOnSleep,
      'targetAppsToClose': targetAppsToClose,
      'savedWatchId': savedWatchId,
      'savedWatchName': savedWatchName,
      'learnedSleepingBpm': learnedSleepingBpm,
      'languageCode': languageCode,
      'isProUnlocked': isProUnlocked,
    };
  }

  factory SleepSettings.fromJson(Map<String, dynamic> json) {
    final modeName = json['preferredMode'] as String?;
    final mode = DetectionMode.values.firstWhere(
      (e) => e.name == modeName,
      orElse: () => DetectionMode.watchBle,
    );

    final trigName = json['biometricTriggerMode'] as String?;
    final trigMode = BiometricTriggerMode.values.firstWhere(
      (e) => e.name == trigName,
      orElse: () => BiometricTriggerMode.smartAdaptive,
    );

    final sensName = json['adaptiveSensitivity'] as String?;
    final sens = AdaptiveSensitivity.values.firstWhere(
      (e) => e.name == sensName,
      orElse: () => AdaptiveSensitivity.balanced,
    );

    Map<String, String> parsedTargetApps = defaultTargetApps;
    if (json['targetAppsToClose'] is Map) {
      final rawMap = json['targetAppsToClose'] as Map;
      parsedTargetApps = rawMap.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    }

    return SleepSettings(
      preferredMode: mode,
      biometricTriggerMode: trigMode,
      adaptiveSensitivity: sens,
      sleepBpmThreshold: (json['sleepBpmThreshold'] as num?)?.toInt() ?? 55,
      useAutoBaseline: json['useAutoBaseline'] as bool? ?? true,
      autoBaselineDropPercent:
          (json['autoBaselineDropPercent'] as num?)?.toDouble() ?? 10.0,
      confirmationDurationMinutes:
          (json['confirmationDurationMinutes'] as num?)?.toInt() ?? 4,
      checkIntervalMinutes:
          (json['checkIntervalMinutes'] as num?)?.toInt() ?? 15,
      shakeSensitivity: (json['shakeSensitivity'] as num?)?.toDouble() ?? 1.8,
      rewindOnPause: json['rewindOnPause'] as bool? ?? false,
      closeAppsOnSleep: json['closeAppsOnSleep'] as bool? ?? true,
      returnToHomeOnSleep: json['returnToHomeOnSleep'] as bool? ?? true,
      targetAppsToClose: parsedTargetApps,
      savedWatchId: json['savedWatchId'] as String?,
      savedWatchName: json['savedWatchName'] as String?,
      learnedSleepingBpm: (json['learnedSleepingBpm'] as num?)?.toDouble(),
      languageCode: (json['languageCode'] as String?) ?? 'fr',
      isProUnlocked: json['isProUnlocked'] as bool? ?? false,
    );
  }

  String encode() => jsonEncode(toJson());

  static SleepSettings decode(String raw) {
    try {
      return SleepSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SleepSettings();
    }
  }
}
