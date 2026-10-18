import 'sleep_settings.dart';

enum SessionPhase {
  idle,
  scanningBle,
  connectingBle,
  calibratingBaseline,
  monitoring,
  hrDropping,
  fadingAudio,

  /// Media is paused; the user has ~90 s to say "still awake" and resume.
  graceWindow,

  /// No heart-rate packet for a while (watch out of range / disconnected).
  signalLost,
  pausedCompleted,
  error,
}

class DiscoveredBleWatch {
  final String id;
  final String name;
  final int rssi;
  final bool advertisesHrService;

  const DiscoveredBleWatch({
    required this.id,
    required this.name,
    required this.rssi,
    required this.advertisesHrService,
  });
}

class ActiveSessionState {
  final bool isRunning;
  final SessionPhase phase;
  final DetectionMode activeMode;
  final String statusText;
  final String? detailText;
  final DateTime? sessionStartTime;
  final int elapsedSeconds;

  // Watch (BLE) & Smart Adaptive Biometric fields
  final String? connectedWatchName;
  final String? connectedWatchId;
  final int? currentBpm;
  final double? baselineBpm;
  final int? effectiveThresholdBpm;
  final double? bpmStabilityStdDev;
  final int? latestRrIntervalMs;
  final double? hrvRmssdMs;
  final double sleepConfidenceScore;
  final int consecutiveLowHrSeconds;
  final int requiredLowHrSeconds;
  final List<DiscoveredBleWatch> discoveredWatches;

  /// 0..1 while the awake baseline is being learned.
  final double calibrationProgress;

  /// Seconds since the last heart-rate packet exceeded the staleness limit.
  final int signalLostSeconds;

  /// Seconds left in the "still awake?" window after a pause.
  final int graceRemainingSeconds;

  /// How many times the user said "still awake" tonight.
  final int stillAwakeCount;

  /// BPM sampled every 30 s since the session started (night curve).
  final List<int> bpmTimeline;

  // Phone (Fade & Shake) fields
  final int checkIntervalRemainingSeconds;
  final int checkIntervalTotalSeconds;
  final double lastShakeMagnitude;
  final int shakeResetCount;

  // Volume Fade fields
  final bool isFading;
  final int fadeRemainingSeconds;
  final int fadeTotalSeconds;
  final int? originalVolume;
  final int? currentVolume;
  final int? maxVolume;

  const ActiveSessionState({
    this.isRunning = false,
    this.phase = SessionPhase.idle,
    this.activeMode = DetectionMode.watchBle,
    this.statusText = 'Ready to start sleep session',
    this.detailText,
    this.sessionStartTime,
    this.elapsedSeconds = 0,
    this.connectedWatchName,
    this.connectedWatchId,
    this.currentBpm,
    this.baselineBpm,
    this.effectiveThresholdBpm,
    this.bpmStabilityStdDev,
    this.latestRrIntervalMs,
    this.hrvRmssdMs,
    this.sleepConfidenceScore = 0.0,
    this.consecutiveLowHrSeconds = 0,
    this.requiredLowHrSeconds = 240,
    this.discoveredWatches = const [],
    this.calibrationProgress = 0.0,
    this.signalLostSeconds = 0,
    this.graceRemainingSeconds = 0,
    this.stillAwakeCount = 0,
    this.bpmTimeline = const [],
    this.checkIntervalRemainingSeconds = 0,
    this.checkIntervalTotalSeconds = 900,
    this.lastShakeMagnitude = 0.0,
    this.shakeResetCount = 0,
    this.isFading = false,
    this.fadeRemainingSeconds = 0,
    this.fadeTotalSeconds = 0,
    this.originalVolume,
    this.currentVolume,
    this.maxVolume,
  });

  bool get isSignalStale => phase == SessionPhase.signalLost;
  bool get isInGraceWindow => phase == SessionPhase.graceWindow;

  double get lowHrProgress {
    if (requiredLowHrSeconds <= 0) return 0.0;
    return (consecutiveLowHrSeconds / requiredLowHrSeconds).clamp(0.0, 1.0);
  }

  double get fadeProgress {
    if (fadeTotalSeconds <= 0) return 0.0;
    return ((fadeTotalSeconds - fadeRemainingSeconds) / fadeTotalSeconds).clamp(
      0.0,
      1.0,
    );
  }

  ActiveSessionState copyWith({
    bool? isRunning,
    SessionPhase? phase,
    DetectionMode? activeMode,
    String? statusText,
    String? detailText,
    bool clearDetailText = false,
    DateTime? sessionStartTime,
    bool clearSessionStartTime = false,
    int? elapsedSeconds,
    String? connectedWatchName,
    bool clearConnectedWatch = false,
    String? connectedWatchId,
    int? currentBpm,
    bool clearCurrentBpm = false,
    double? baselineBpm,
    bool clearBaselineBpm = false,
    int? effectiveThresholdBpm,
    double? bpmStabilityStdDev,
    int? latestRrIntervalMs,
    double? hrvRmssdMs,
    double? sleepConfidenceScore,
    int? consecutiveLowHrSeconds,
    int? requiredLowHrSeconds,
    List<DiscoveredBleWatch>? discoveredWatches,
    double? calibrationProgress,
    int? signalLostSeconds,
    int? graceRemainingSeconds,
    int? stillAwakeCount,
    List<int>? bpmTimeline,
    int? checkIntervalRemainingSeconds,
    int? checkIntervalTotalSeconds,
    double? lastShakeMagnitude,
    int? shakeResetCount,
    bool? isFading,
    int? fadeRemainingSeconds,
    int? fadeTotalSeconds,
    int? originalVolume,
    int? currentVolume,
    int? maxVolume,
  }) {
    return ActiveSessionState(
      isRunning: isRunning ?? this.isRunning,
      phase: phase ?? this.phase,
      activeMode: activeMode ?? this.activeMode,
      statusText: statusText ?? this.statusText,
      detailText: clearDetailText ? null : (detailText ?? this.detailText),
      sessionStartTime: clearSessionStartTime
          ? null
          : (sessionStartTime ?? this.sessionStartTime),
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      connectedWatchName: clearConnectedWatch
          ? null
          : (connectedWatchName ?? this.connectedWatchName),
      connectedWatchId: clearConnectedWatch
          ? null
          : (connectedWatchId ?? this.connectedWatchId),
      currentBpm: clearCurrentBpm ? null : (currentBpm ?? this.currentBpm),
      baselineBpm: clearBaselineBpm ? null : (baselineBpm ?? this.baselineBpm),
      effectiveThresholdBpm:
          effectiveThresholdBpm ?? this.effectiveThresholdBpm,
      bpmStabilityStdDev: bpmStabilityStdDev ?? this.bpmStabilityStdDev,
      latestRrIntervalMs: latestRrIntervalMs ?? this.latestRrIntervalMs,
      hrvRmssdMs: hrvRmssdMs ?? this.hrvRmssdMs,
      sleepConfidenceScore: sleepConfidenceScore ?? this.sleepConfidenceScore,
      consecutiveLowHrSeconds:
          consecutiveLowHrSeconds ?? this.consecutiveLowHrSeconds,
      requiredLowHrSeconds: requiredLowHrSeconds ?? this.requiredLowHrSeconds,
      discoveredWatches: discoveredWatches ?? this.discoveredWatches,
      calibrationProgress: calibrationProgress ?? this.calibrationProgress,
      signalLostSeconds: signalLostSeconds ?? this.signalLostSeconds,
      graceRemainingSeconds: graceRemainingSeconds ?? this.graceRemainingSeconds,
      stillAwakeCount: stillAwakeCount ?? this.stillAwakeCount,
      bpmTimeline: bpmTimeline ?? this.bpmTimeline,
      checkIntervalRemainingSeconds:
          checkIntervalRemainingSeconds ?? this.checkIntervalRemainingSeconds,
      checkIntervalTotalSeconds:
          checkIntervalTotalSeconds ?? this.checkIntervalTotalSeconds,
      lastShakeMagnitude: lastShakeMagnitude ?? this.lastShakeMagnitude,
      shakeResetCount: shakeResetCount ?? this.shakeResetCount,
      isFading: isFading ?? this.isFading,
      fadeRemainingSeconds: fadeRemainingSeconds ?? this.fadeRemainingSeconds,
      fadeTotalSeconds: fadeTotalSeconds ?? this.fadeTotalSeconds,
      originalVolume: originalVolume ?? this.originalVolume,
      currentVolume: currentVolume ?? this.currentVolume,
      maxVolume: maxVolume ?? this.maxVolume,
    );
  }
}
