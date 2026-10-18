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
  final String? redeemedVipCode;
  final bool anonymousTelemetryEnabled;

  /// Nights where sleep onset was detected while not Pro. Persisted here (not
  /// derived from the history) so clearing the history cannot reset the trial.
  final int trialNightsUsed;

  /// True once the first-start permission explainer has been shown.
  final bool onboardingPermissionsShown;

  /// True once the 4-page introduction has been completed or skipped.
  final bool onboardingCompleted;

  /// Runtime only (never persisted): false until settings were read from
  /// disk, so the root widget can avoid flashing the onboarding to returning
  /// users.
  final bool isHydrated;

  /// "When I fall asleep" module (lights, intent, webhook). Off by default.
  final SleepActionsSettings sleepActions;

  static const int totalFreeTrialNights = 5;

  int get remainingTrialNights =>
      (totalFreeTrialNights - trialNightsUsed).clamp(0, totalFreeTrialNights);

  const SleepSettings({
    this.preferredMode = DetectionMode.watchBle,
    this.biometricTriggerMode = BiometricTriggerMode.smartAdaptive,
    this.adaptiveSensitivity = AdaptiveSensitivity.balanced,
    this.sleepBpmThreshold = 55,
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
    this.redeemedVipCode,
    this.anonymousTelemetryEnabled = true,
    this.trialNightsUsed = 0,
    this.onboardingPermissionsShown = false,
    this.onboardingCompleted = false,
    this.isHydrated = false,
    this.sleepActions = const SleepActionsSettings(),
  });

  SleepSettings copyWith({
    DetectionMode? preferredMode,
    BiometricTriggerMode? biometricTriggerMode,
    AdaptiveSensitivity? adaptiveSensitivity,
    int? sleepBpmThreshold,
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
    String? redeemedVipCode,
    bool clearRedeemedVipCode = false,
    bool? anonymousTelemetryEnabled,
    int? trialNightsUsed,
    bool? onboardingPermissionsShown,
    bool? onboardingCompleted,
    bool? isHydrated,
    SleepActionsSettings? sleepActions,
  }) {
    return SleepSettings(
      preferredMode: preferredMode ?? this.preferredMode,
      biometricTriggerMode: biometricTriggerMode ?? this.biometricTriggerMode,
      adaptiveSensitivity: adaptiveSensitivity ?? this.adaptiveSensitivity,
      sleepBpmThreshold: sleepBpmThreshold ?? this.sleepBpmThreshold,
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
      redeemedVipCode: clearRedeemedVipCode
          ? null
          : (redeemedVipCode ?? this.redeemedVipCode),
      anonymousTelemetryEnabled:
          anonymousTelemetryEnabled ?? this.anonymousTelemetryEnabled,
      trialNightsUsed: trialNightsUsed ?? this.trialNightsUsed,
      onboardingPermissionsShown:
          onboardingPermissionsShown ?? this.onboardingPermissionsShown,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isHydrated: isHydrated ?? this.isHydrated,
      sleepActions: sleepActions ?? this.sleepActions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferredMode': preferredMode.name,
      'biometricTriggerMode': biometricTriggerMode.name,
      'adaptiveSensitivity': adaptiveSensitivity.name,
      'sleepBpmThreshold': sleepBpmThreshold,
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
      'redeemedVipCode': redeemedVipCode,
      'anonymousTelemetryEnabled': anonymousTelemetryEnabled,
      'trialNightsUsed': trialNightsUsed,
      'onboardingPermissionsShown': onboardingPermissionsShown,
      'onboardingCompleted': onboardingCompleted,
      'sleepActions': sleepActions.toJson(),
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
      redeemedVipCode: json['redeemedVipCode'] as String?,
      anonymousTelemetryEnabled:
          json['anonymousTelemetryEnabled'] as bool? ?? true,
      trialNightsUsed: (json['trialNightsUsed'] as num?)?.toInt() ?? 0,
      onboardingPermissionsShown:
          json['onboardingPermissionsShown'] as bool? ?? false,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      isHydrated: true,
      sleepActions: json['sleepActions'] is Map
          ? SleepActionsSettings.fromJson(
              Map<String, dynamic>.from(json['sleepActions'] as Map),
            )
          : const SleepActionsSettings(),
    );
  }

  String encode() => jsonEncode(toJson());

  static SleepSettings decode(String raw) {
    try {
      return SleepSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SleepSettings(isHydrated: true);
    }
  }
}

// ---------------------------------------------------------------------------
// "When I fall asleep" module settings
// ---------------------------------------------------------------------------

enum LightsFadeDuration { instant, s30, m1, m2 }

extension LightsFadeDurationX on LightsFadeDuration {
  int get seconds => switch (this) {
    LightsFadeDuration.instant => 0,
    LightsFadeDuration.s30 => 30,
    LightsFadeDuration.m1 => 60,
    LightsFadeDuration.m2 => 120,
  };
}

class LightsActionSettings {
  final bool enabled;
  final List<String> deviceIds;
  final List<String> roomIds;
  final LightsFadeDuration fade;

  const LightsActionSettings({
    this.enabled = false,
    this.deviceIds = const [],
    this.roomIds = const [],
    this.fade = LightsFadeDuration.s30,
  });

  LightsActionSettings copyWith({
    bool? enabled,
    List<String>? deviceIds,
    List<String>? roomIds,
    LightsFadeDuration? fade,
  }) => LightsActionSettings(
    enabled: enabled ?? this.enabled,
    deviceIds: deviceIds ?? this.deviceIds,
    roomIds: roomIds ?? this.roomIds,
    fade: fade ?? this.fade,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'deviceIds': deviceIds,
    'roomIds': roomIds,
    'fade': fade.name,
  };

  factory LightsActionSettings.fromJson(Map<String, dynamic> json) =>
      LightsActionSettings(
        enabled: json['enabled'] as bool? ?? false,
        deviceIds: (json['deviceIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        roomIds: (json['roomIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        fade: LightsFadeDuration.values.firstWhere(
          (f) => f.name == json['fade'],
          orElse: () => LightsFadeDuration.s30,
        ),
      );
}

class IntentActionSettings {
  final bool enabled;
  const IntentActionSettings({this.enabled = false});
  IntentActionSettings copyWith({bool? enabled}) =>
      IntentActionSettings(enabled: enabled ?? this.enabled);
  Map<String, dynamic> toJson() => {'enabled': enabled};
  factory IntentActionSettings.fromJson(Map<String, dynamic> json) =>
      IntentActionSettings(enabled: json['enabled'] as bool? ?? false);
}

class WebhookActionSettings {
  final bool enabled;
  final String url;

  /// The secret itself lives in secure storage; this only drives the UI.
  final bool hasSecret;

  const WebhookActionSettings({
    this.enabled = false,
    this.url = '',
    this.hasSecret = false,
  });

  WebhookActionSettings copyWith({bool? enabled, String? url, bool? hasSecret}) =>
      WebhookActionSettings(
        enabled: enabled ?? this.enabled,
        url: url ?? this.url,
        hasSecret: hasSecret ?? this.hasSecret,
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'url': url,
    'hasSecret': hasSecret,
  };

  factory WebhookActionSettings.fromJson(Map<String, dynamic> json) =>
      WebhookActionSettings(
        enabled: json['enabled'] as bool? ?? false,
        url: json['url'] as String? ?? '',
        hasSecret: json['hasSecret'] as bool? ?? false,
      );
}

class SleepActionsSettings {
  /// Master switch: when false nothing runs, whatever the per-action toggles.
  final bool enabled;
  final LightsActionSettings lights;
  final IntentActionSettings intent;
  final WebhookActionSettings webhook;

  const SleepActionsSettings({
    this.enabled = false,
    this.lights = const LightsActionSettings(),
    this.intent = const IntentActionSettings(),
    this.webhook = const WebhookActionSettings(),
  });

  int get activeCount =>
      (lights.enabled ? 1 : 0) + (intent.enabled ? 1 : 0) + (webhook.enabled ? 1 : 0);

  SleepActionsSettings copyWith({
    bool? enabled,
    LightsActionSettings? lights,
    IntentActionSettings? intent,
    WebhookActionSettings? webhook,
  }) => SleepActionsSettings(
    enabled: enabled ?? this.enabled,
    lights: lights ?? this.lights,
    intent: intent ?? this.intent,
    webhook: webhook ?? this.webhook,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'lights': lights.toJson(),
    'intent': intent.toJson(),
    'webhook': webhook.toJson(),
  };

  factory SleepActionsSettings.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> sub(String key) => json[key] is Map
        ? Map<String, dynamic>.from(json[key] as Map)
        : const <String, dynamic>{};
    return SleepActionsSettings(
      enabled: json['enabled'] as bool? ?? false,
      lights: LightsActionSettings.fromJson(sub('lights')),
      intent: IntentActionSettings.fromJson(sub('intent')),
      webhook: WebhookActionSettings.fromJson(sub('webhook')),
    );
  }
}
