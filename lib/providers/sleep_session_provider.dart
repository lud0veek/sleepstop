import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/active_session_state.dart';
import '../models/sleep_session_log.dart';
import '../models/sleep_settings.dart';
import '../services/ble_heart_rate_service.dart';
import '../services/foreground_task_service.dart';
import '../services/media_control_service.dart';
import '../services/motion_detector_service.dart';
import '../services/notification_service.dart';
import 'session_logs_provider.dart';
import 'settings_provider.dart';

final mediaControlServiceProvider = Provider<MediaControlService>((ref) {
  final service = MediaControlService();
  ref.onDispose(service.dispose);
  return service;
});

final bleHeartRateServiceProvider = Provider<BleHeartRateService>((ref) {
  final service = BleHeartRateService();
  ref.onDispose(service.dispose);
  return service;
});

final motionDetectorServiceProvider = Provider<MotionDetectorService>((ref) {
  final service = MotionDetectorService();
  ref.onDispose(service.dispose);
  return service;
});

final sleepSessionProvider =
    NotifierProvider<SleepSessionNotifier, ActiveSessionState>(
      SleepSessionNotifier.new,
    );

class SleepSessionNotifier extends Notifier<ActiveSessionState> {
  static const int _smartCalibrationSeconds = 90;

  late final MediaControlService _mediaControl;
  late final BleHeartRateService _bleService;
  late final MotionDetectorService _motionService;

  Timer? _sessionTicker;
  Timer? _simulatedHrTimer;
  StreamSubscription<HeartRatePacket>? _packetSubscription;
  StreamSubscription<List<DiscoveredBleWatch>>? _watchesSubscription;
  StreamSubscription<String>? _bleStatusSubscription;

  final List<int> _baselineSamples = [];
  final List<int> _rolling60sBpms = [];
  final List<int> _rollingRrIntervalsMs = [];
  final List<int> _sessionBpmTimeline = [];
  ActiveMediaInfo? _lastKnownMediaInfo;
  DateTime? _fadeStartedAt;
  bool _isStoppingOrCompleting = false;

  @override
  ActiveSessionState build() {
    _mediaControl = ref.read(mediaControlServiceProvider);
    _bleService = ref.read(bleHeartRateServiceProvider);
    _motionService = ref.read(motionDetectorServiceProvider);

    FlutterForegroundTask.addTaskDataCallback(_onForegroundTaskData);
    _mediaControl.setQuickTileToggleListener(_handleQuickTileToggle);

    Future.microtask(() async {
      final launchedFromTile = await _mediaControl
          .consumeQuickTileLaunchTrigger();
      if (launchedFromTile && !state.isRunning) {
        await startSession();
      } else {
        await _mediaControl.updateQuickTileState(
          isActive: state.isRunning,
          subtitle: state.isRunning ? 'Veille active' : 'Prêt à veiller',
        );
      }
    });

    _watchesSubscription = _bleService.discoveredWatchesStream.listen((
      watches,
    ) {
      state = state.copyWith(discoveredWatches: watches);
    });

    _bleStatusSubscription = _bleService.connectionStatusStream.listen((msg) {
      if (state.isRunning && state.activeMode == DetectionMode.watchBle) {
        state = state.copyWith(detailText: msg);
      }
    });

    ref.onDispose(() {
      FlutterForegroundTask.removeTaskDataCallback(_onForegroundTaskData);
      _sessionTicker?.cancel();
      _simulatedHrTimer?.cancel();
      _packetSubscription?.cancel();
      _watchesSubscription?.cancel();
      _bleStatusSubscription?.cancel();
    });

    final preferredMode = ref.read(settingsProvider).preferredMode;
    return ActiveSessionState(activeMode: preferredMode);
  }

  void _handleQuickTileToggle() {
    if (state.isRunning) {
      stopSession(reason: 'Stopped from Android Quick Settings Tile');
    } else {
      startSession();
    }
  }

  Future<String> requestAddQuickTile() {
    return _mediaControl.requestAddQuickSettingsTile();
  }

  void _onForegroundTaskData(Object data) {
    if (data is Map && data['event'] == 'stop_session') {
      stopSession(reason: 'Stopped from notification');
    }
  }

  void selectMode(DetectionMode mode) {
    if (state.isRunning) return;
    ref.read(settingsProvider.notifier).setPreferredMode(mode);
    state = state.copyWith(
      activeMode: mode,
      phase: SessionPhase.idle,
      statusText: 'Ready to start sleep session',
      clearDetailText: true,
    );
  }

  Future<void> startSession({bool simulateBleWatch = false}) async {
    if (state.isRunning) return;
    _isStoppingOrCompleting = false;

    final settings = ref.read(settingsProvider);
    final mode = state.activeMode;
    final startTime = DateTime.now();
    final initialVol = await _mediaControl.getCurrentVolume();
    final maxVol = await _mediaControl.getMaxVolume();
    _lastKnownMediaInfo = await _mediaControl.getActiveMediaInfo();

    if (mode == DetectionMode.watchBle) {
      await _startWatchBleSession(
        settings: settings,
        startTime: startTime,
        initialVolume: initialVol,
        maxVolume: maxVol,
        simulateBleWatch: simulateBleWatch,
      );
    } else {
      await _startPhoneFadeShakeSession(
        settings: settings,
        startTime: startTime,
        initialVolume: initialVol,
        maxVolume: maxVol,
      );
    }
  }

  Future<void> _startWatchBleSession({
    required SleepSettings settings,
    required DateTime startTime,
    required int initialVolume,
    required int maxVolume,
    required bool simulateBleWatch,
  }) async {
    _baselineSamples.clear();
    _rolling60sBpms.clear();
    _rollingRrIntervalsMs.clear();
    _sessionBpmTimeline.clear();

    final isSmart =
        settings.biometricTriggerMode == BiometricTriggerMode.smartAdaptive;
    final requiredLowSeconds = settings.confirmationDurationMinutes * 60;
    final initialTarget = isSmart
        ? (settings.learnedSleepingBpm?.round() ?? settings.sleepBpmThreshold)
        : settings.sleepBpmThreshold;

    state = ActiveSessionState(
      isRunning: true,
      phase: simulateBleWatch
          ? (isSmart
                ? SessionPhase.calibratingBaseline
                : SessionPhase.monitoring)
          : SessionPhase.scanningBle,
      activeMode: DetectionMode.watchBle,
      statusText: simulateBleWatch
          ? (isSmart ? 'Calibrating baseline (90s)...' : 'Monitoring...')
          : 'Connecting to Garmin / BLE Watch (0x180D)...',
      detailText: simulateBleWatch
          ? 'Simulated Firstbeat HR + R-R stream active'
          : 'Looking for your paired Garmin or BLE watch...',
      sessionStartTime: startTime,
      elapsedSeconds: 0,
      effectiveThresholdBpm: initialTarget,
      consecutiveLowHrSeconds: 0,
      requiredLowHrSeconds: requiredLowSeconds,
      originalVolume: initialVolume,
      currentVolume: initialVolume,
      maxVolume: maxVolume,
    );

    await ForegroundTaskService.instance.startMonitoringService(
      title: 'SleepStop • Watch Biometric Mode',
      text: simulateBleWatch
          ? 'Monitoring simulated BLE Heart Rate...'
          : 'Connecting to BLE Heart Rate watch...',
    );
    await _mediaControl.updateQuickTileState(
      isActive: true,
      subtitle: simulateBleWatch
          ? 'Veille simulée active'
          : 'Connexion montre...',
    );

    if (simulateBleWatch) {
      state = state.copyWith(
        connectedWatchName: 'Garmin Watch (Simulated Firstbeat)',
        connectedWatchId: 'SIM-GARMIN-180D',
      );
      _startSimulatedHeartRateFeed(settings);
      _startWatchSessionTicker();
      return;
    }

    await _packetSubscription?.cancel();
    _packetSubscription = _bleService.packetStream.listen(
      _onNewHeartRatePacket,
    );

    final device = await _bleService.scanAndConnect(
      preferredDeviceId: settings.savedWatchId,
      timeout: const Duration(seconds: 10),
    );

    if (!state.isRunning) return;

    if (device == null) {
      await _packetSubscription?.cancel();
      _packetSubscription = null;
      await ForegroundTaskService.instance.stopMonitoringService();
      await _mediaControl.updateQuickTileState(
        isActive: false,
        subtitle: 'Montre non trouvée',
      );
      state = state.copyWith(
        isRunning: false,
        phase: SessionPhase.error,
        statusText: 'No BLE Heart Rate watch found (0x180D)',
        detailText:
            state.detailText ??
            'Turn on "Broadcast HR" on your Garmin watch, or tap "Simulate Watch HR" below to test.',
      );
      return;
    }

    final watchName =
        (_bleService.resolvedWatchName != null &&
            _bleService.resolvedWatchName!.isNotEmpty)
        ? _bleService.resolvedWatchName!
        : (device.platformName.isNotEmpty
              ? device.platformName
              : 'Garmin Watch (${device.remoteId.str})');

    await ref
        .read(settingsProvider.notifier)
        .setSavedWatch(id: device.remoteId.str, name: watchName);

    state = state.copyWith(
      phase: isSmart
          ? SessionPhase.calibratingBaseline
          : SessionPhase.monitoring,
      connectedWatchName: watchName,
      connectedWatchId: device.remoteId.str,
      statusText: isSmart
          ? 'Calibrating baseline (90s)...'
          : 'Monitoring...',
      detailText: 'Connected to $watchName (0x2A37)',
    );
    await _mediaControl.updateQuickTileState(
      isActive: true,
      subtitle: 'Actif • $watchName',
    );

    _startWatchSessionTicker();
  }

  void _startSimulatedHeartRateFeed(SleepSettings settings) {
    _simulatedHrTimer?.cancel();
    int tick = 0;
    final rng = math.Random();
    _simulatedHrTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      tick++;
      int bpm;
      if (tick <= 12) {
        bpm = 64 + rng.nextInt(5) - 2;
      } else if (tick <= 25) {
        bpm = (64 - ((tick - 12) * 0.7)).round();
      } else {
        final target = settings.sleepBpmThreshold - 2;
        bpm = target + (tick % 2 == 0 ? 0 : -1);
      }
      final rrMs = (60000 / bpm).round() + (tick <= 12 ? rng.nextInt(35) : 6);
      _onNewHeartRatePacket(HeartRatePacket(bpm: bpm, rrIntervalsMs: [rrMs]));
    });
  }

  int _computeSmartAdaptiveThreshold({
    required double awakeBaselineBpm,
    required SleepSettings settings,
  }) {
    final baseDropRatio = switch (settings.adaptiveSensitivity) {
      AdaptiveSensitivity.fast => 0.065,
      AdaptiveSensitivity.balanced => 0.085,
      AdaptiveSensitivity.deep => 0.105,
    };

    final lowHrScale = awakeBaselineBpm < 60.0
        ? ((awakeBaselineBpm - 42.0) / 18.0).clamp(0.45, 1.0)
        : 1.0;

    final dropBpm = (awakeBaselineBpm * baseDropRatio * lowHrScale).clamp(
      2.0,
      11.0,
    );
    double rawTarget = awakeBaselineBpm - dropBpm;

    if (settings.learnedSleepingBpm != null) {
      rawTarget = (rawTarget * 0.75) + (settings.learnedSleepingBpm! * 0.25);
      if (rawTarget > awakeBaselineBpm - 2.0) {
        rawTarget = awakeBaselineBpm - 2.0;
      }
    }

    return rawTarget.round().clamp(40, 95);
  }

  void _onNewHeartRatePacket(HeartRatePacket packet) {
    if (!state.isRunning || state.isFading) return;

    final bpm = packet.bpm;
    final settings = ref.read(settingsProvider);
    final isSmart =
        settings.biometricTriggerMode == BiometricTriggerMode.smartAdaptive;

    _rolling60sBpms.add(bpm);
    if (_rolling60sBpms.length > 60) {
      _rolling60sBpms.removeAt(0);
    }

    // Record timeline sample every ~10 readings (capped at 120 points)
    if (_sessionBpmTimeline.isEmpty || _rolling60sBpms.length % 10 == 0) {
      _sessionBpmTimeline.add(bpm);
      if (_sessionBpmTimeline.length > 120) {
        _sessionBpmTimeline.removeAt(0);
      }
    }

    double? stdDevBpm;
    if (_rolling60sBpms.length >= 6) {
      final mean =
          _rolling60sBpms.fold<int>(0, (a, b) => a + b) /
          _rolling60sBpms.length;
      final variance =
          _rolling60sBpms.fold<double>(
            0.0,
            (sum, val) => sum + ((val - mean) * (val - mean)),
          ) /
          _rolling60sBpms.length;
      stdDevBpm = math.sqrt(variance);
    }

    int? latestRrMs = state.latestRrIntervalMs;
    double? rmssd = state.hrvRmssdMs;
    if (packet.rrIntervalsMs.isNotEmpty) {
      latestRrMs = packet.rrIntervalsMs.last;
      _rollingRrIntervalsMs.addAll(packet.rrIntervalsMs);
      while (_rollingRrIntervalsMs.length > 45) {
        _rollingRrIntervalsMs.removeAt(0);
      }
      if (_rollingRrIntervalsMs.length >= 4) {
        double sumSqDiff = 0.0;
        for (int i = 1; i < _rollingRrIntervalsMs.length; i++) {
          final diff =
              (_rollingRrIntervalsMs[i] - _rollingRrIntervalsMs[i - 1])
                  .toDouble();
          sumSqDiff += diff * diff;
        }
        rmssd = math.sqrt(sumSqDiff / (_rollingRrIntervalsMs.length - 1));
      }
    }

    double? baseline = state.baselineBpm;
    int threshold = settings.sleepBpmThreshold;

    if (isSmart) {
      if (state.elapsedSeconds <= _smartCalibrationSeconds ||
          _baselineSamples.length < 15) {
        _baselineSamples.add(bpm);
        final sorted = List<int>.from(_baselineSamples)..sort();
        final p75Index = ((sorted.length - 1) * 0.75).round();
        baseline = sorted[p75Index].toDouble();
      }
      if (baseline != null) {
        threshold = _computeSmartAdaptiveThreshold(
          awakeBaselineBpm: baseline,
          settings: settings,
        );
      }
    } else if (settings.useAutoBaseline) {
      if (state.elapsedSeconds <= 180) {
        _baselineSamples.add(bpm);
        final sum = _baselineSamples.fold<int>(0, (a, b) => a + b);
        baseline = sum / _baselineSamples.length;
      }
      if (baseline != null) {
        threshold = (baseline * (1.0 - settings.autoBaselineDropPercent / 100))
            .round()
            .clamp(38, 110);
      }
    }

    state = state.copyWith(
      currentBpm: bpm,
      baselineBpm: baseline,
      effectiveThresholdBpm: threshold,
      bpmStabilityStdDev: stdDevBpm,
      latestRrIntervalMs: latestRrMs,
      hrvRmssdMs: rmssd,
    );
  }

  void _startWatchSessionTicker() {
    _sessionTicker?.cancel();
    _sessionTicker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!state.isRunning || state.isFading || _isStoppingOrCompleting) return;

      final settings = ref.read(settingsProvider);
      final isSmart =
          settings.biometricTriggerMode == BiometricTriggerMode.smartAdaptive;
      final elapsed = state.elapsedSeconds + 1;
      final requiredSeconds = settings.confirmationDurationMinutes * 60;
      final bpm = state.currentBpm;
      final threshold =
          state.effectiveThresholdBpm ?? settings.sleepBpmThreshold;
      final stdDev = state.bpmStabilityStdDev;

      // Refresh active media info every 15 seconds while playing
      if (elapsed % 15 == 0) {
        final info = await _mediaControl.getActiveMediaInfo();
        if (info.hasData) {
          _lastKnownMediaInfo = info;
        }
      }

      if (isSmart && elapsed < _smartCalibrationSeconds) {
        final secsLeft = _smartCalibrationSeconds - elapsed;
        state = state.copyWith(
          elapsedSeconds: elapsed,
          phase: SessionPhase.calibratingBaseline,
          statusText: 'Calibrating baseline (${secsLeft}s)...',
          requiredLowHrSeconds: requiredSeconds,
        );
        return;
      }

      bool matchesSleepPattern = false;
      String reasonSuffix = '';

      if (bpm != null) {
        if (isSmart) {
          final maxAllowedStdDev = switch (settings.adaptiveSensitivity) {
            AdaptiveSensitivity.fast => 2.4,
            AdaptiveSensitivity.balanced => 1.9,
            AdaptiveSensitivity.deep => 1.5,
          };
          final isStable = stdDev == null || stdDev <= maxAllowedStdDev;
          final isUltraStablePlateau = stdDev != null && stdDev <= 1.2;
          final droppedBelowTarget = bpm <= threshold;
          final droppedFromAwake =
              state.baselineBpm != null && bpm <= (state.baselineBpm! - 2.0);

          if ((droppedBelowTarget && isStable) ||
              (droppedFromAwake && isUltraStablePlateau)) {
            matchesSleepPattern = true;
            reasonSuffix = stdDev != null
                ? '±${stdDev.toStringAsFixed(1)} BPM'
                : '≤ $threshold BPM';
          }
        } else {
          matchesSleepPattern = bpm <= threshold;
          reasonSuffix = '≤ $threshold BPM';
        }
      }

      int lowSeconds = state.consecutiveLowHrSeconds;
      SessionPhase phase = SessionPhase.monitoring;
      String statusText = 'Monitoring...';

      if (matchesSleepPattern) {
        lowSeconds++;
        final currentMin = (lowSeconds ~/ 60) + 1;
        final totalMin = settings.confirmationDurationMinutes;
        phase = SessionPhase.hrDropping;
        statusText = isSmart
            ? 'Sleep onset (${currentMin.clamp(1, totalMin)}/$totalMin min • $reasonSuffix)...'
            : 'HR dropping (${currentMin.clamp(1, totalMin)}/$totalMin min)...';
      } else {
        lowSeconds = isSmart ? (lowSeconds - 2).clamp(0, requiredSeconds) : 0;
        phase = lowSeconds > 0
            ? SessionPhase.hrDropping
            : SessionPhase.monitoring;
        statusText = lowSeconds > 0 ? 'Stabilizing HR...' : 'Monitoring...';
      }

      final confidence = (lowSeconds / requiredSeconds).clamp(0.0, 1.0);

      state = state.copyWith(
        elapsedSeconds: elapsed,
        consecutiveLowHrSeconds: lowSeconds,
        requiredLowHrSeconds: requiredSeconds,
        sleepConfidenceScore: confidence,
        phase: phase,
        statusText: statusText,
      );

      if (elapsed % 5 == 0) {
        final bpmLabel = bpm != null ? '$bpm BPM' : '-- BPM';
        await ForegroundTaskService.instance.updateNotification(
          title: 'SleepStop • $bpmLabel (Target ≤ $threshold BPM)',
          text: statusText,
        );
        await _mediaControl.updateQuickTileState(
          isActive: true,
          subtitle: 'Actif • $bpmLabel (≤$threshold)',
        );
      }

      if (lowSeconds >= requiredSeconds) {
        await _triggerWatchSleepDetected(
          finalBpm: bpm ?? threshold,
          threshold: threshold,
          isSmartAdaptive: isSmart,
          stdDevBpm: stdDev,
        );
      }
    });
  }

  Future<void> _triggerWatchSleepDetected({
    required int finalBpm,
    required int threshold,
    bool isSmartAdaptive = true,
    double? stdDevBpm,
  }) async {
    if (_isStoppingOrCompleting) return;
    _isStoppingOrCompleting = true;
    _sessionTicker?.cancel();
    _simulatedHrTimer?.cancel();

    final currentMedia = await _mediaControl.getActiveMediaInfo();
    if (currentMedia.hasData) {
      _lastKnownMediaInfo = currentMedia;
    }

    final asleepTime = DateTime.now();
    state = state.copyWith(
      phase: SessionPhase.fadingAudio,
      isFading: true,
      fadeTotalSeconds: 10,
      fadeRemainingSeconds: 10,
      sleepConfidenceScore: 1.0,
      statusText: 'Fading audio...',
      detailText:
          'Sleep onset confirmed at $finalBpm BPM • 10s smooth volume fade-out',
    );

    await ForegroundTaskService.instance.updateNotification(
      title: 'SleepStop • Sleep Confirmed ($finalBpm BPM)',
      text: 'Fading audio over 10 seconds...',
    );

    final completedFade = await _mediaControl.startVolumeFadeOut(
      durationSeconds: 10,
      onProgress: (remaining, currentVol, originalVol, maxVol) {
        if (!state.isRunning) return;
        state = state.copyWith(
          fadeRemainingSeconds: remaining,
          currentVolume: currentVol,
          originalVolume: originalVol,
          maxVolume: maxVol,
          statusText: 'Fading audio (${remaining}s)...',
        );
      },
    );

    if (!completedFade || !state.isRunning) {
      _isStoppingOrCompleting = false;
      return;
    }

    final settings = ref.read(settingsProvider);

    await _mediaControl.pauseAndRestoreVolumeAfterDelay(
      rewindBeforePause: settings.rewindOnPause,
    );

    List<String> closedAppsList = const [];
    if (settings.closeAppsOnSleep) {
      closedAppsList = await _mediaControl.closeTargetApps(
        packages: settings.targetAppsToClose.keys.toList(),
        goHome: settings.returnToHomeOnSleep,
      );
    }

    await _packetSubscription?.cancel();
    _packetSubscription = null;
    await _bleService.disconnect();
    await ForegroundTaskService.instance.stopMonitoringService();
    await _mediaControl.updateQuickTileState(
      isActive: false,
      subtitle: 'Sommeil détecté ($finalBpm BPM)',
    );

    await ref
        .read(settingsProvider.notifier)
        .recordLearnedSleepingBpm(finalBpm);

    final startTime = state.sessionStartTime ?? asleepTime;
    final pausedAtTime = DateTime.now();
    final listeningSeconds = asleepTime
        .difference(startTime)
        .inSeconds
        .clamp(1, 86400);

    final baselineStr = state.baselineBpm != null
        ? 'from ${state.baselineBpm!.toStringAsFixed(0)} BPM '
        : '';
    final stdStr = stdDevBpm != null
        ? ' (±${stdDevBpm.toStringAsFixed(1)} BPM plateau)'
        : '';
    final triggerReason = isSmartAdaptive
        ? 'HR stabilized at $finalBpm BPM $baselineStr$stdStr'
        : 'HR stabilized at $finalBpm BPM';

    if (!_sessionBpmTimeline.contains(finalBpm)) {
      _sessionBpmTimeline.add(finalBpm);
    }

    final log = SleepSessionLog(
      id: pausedAtTime.millisecondsSinceEpoch.toString(),
      mode: DetectionMode.watchBle,
      startTime: startTime,
      asleepTime: asleepTime,
      pausedAtTime: pausedAtTime,
      listeningDurationSeconds: listeningSeconds,
      triggerReason: triggerReason,
      finalBpm: finalBpm,
      baselineBpm: state.baselineBpm,
      watchName: state.connectedWatchName,
      mediaAppName:
          _lastKnownMediaInfo?.appName ??
          (closedAppsList.isNotEmpty ? closedAppsList.join(', ') : null),
      mediaTitle: _lastKnownMediaInfo?.mediaTitle,
      closedApps: closedAppsList,
      bpmTimeline: List<int>.from(_sessionBpmTimeline),
    );

    await ref.read(sessionLogsProvider.notifier).addSessionLog(log);
    await NotificationService.instance.showSleepSummaryNotification(log);

    state = state.copyWith(
      isRunning: false,
      isFading: false,
      phase: SessionPhase.pausedCompleted,
      statusText: 'Sleep detected • Media paused',
      detailText: '$triggerReason. Volume restored.',
    );
    _isStoppingOrCompleting = false;
  }

  // ===========================================================================
  // Detection Mode B: Phone-Only Mode ("Smart Fade & Shake" / Dead Man's Switch)
  // ===========================================================================
  Future<void> _startPhoneFadeShakeSession({
    required SleepSettings settings,
    required DateTime startTime,
    required int initialVolume,
    required int maxVolume,
  }) async {
    final totalIntervalSeconds = settings.checkIntervalMinutes * 60;
    _fadeStartedAt = null;
    _sessionBpmTimeline.clear();

    state = ActiveSessionState(
      isRunning: true,
      phase: SessionPhase.monitoring,
      activeMode: DetectionMode.phoneFadeShake,
      statusText: 'Monitoring...',
      detailText:
          'Shake or tap phone during fade to reset ${settings.checkIntervalMinutes}m timer',
      sessionStartTime: startTime,
      elapsedSeconds: 0,
      checkIntervalRemainingSeconds: totalIntervalSeconds,
      checkIntervalTotalSeconds: totalIntervalSeconds,
      originalVolume: initialVolume,
      currentVolume: initialVolume,
      maxVolume: maxVolume,
    );

    await ForegroundTaskService.instance.startMonitoringService(
      title: 'SleepStop • Phone Fade & Shake Mode',
      text: 'Next sleep check in ${settings.checkIntervalMinutes} min',
    );
    await _mediaControl.updateQuickTileState(
      isActive: true,
      subtitle: 'Actif • Check ${settings.checkIntervalMinutes}m',
    );

    _motionService.startMonitoring(
      threshold: settings.shakeSensitivity,
      onMagnitudeUpdate: (magnitude) {
        if (!state.isRunning) return;
        state = state.copyWith(lastShakeMagnitude: magnitude);
      },
      onShakeDetected: (peakMagnitude) {
        _handlePhoneMovementDetected(peakMagnitude: peakMagnitude);
      },
    );

    _startPhoneCountdownTicker();
  }

  void _startPhoneCountdownTicker() {
    _sessionTicker?.cancel();
    _sessionTicker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!state.isRunning || state.isFading || _isStoppingOrCompleting) return;

      final elapsed = state.elapsedSeconds + 1;
      final remaining = (state.checkIntervalRemainingSeconds - 1).clamp(
        0,
        86400,
      );

      if (elapsed % 15 == 0) {
        final info = await _mediaControl.getActiveMediaInfo();
        if (info.hasData) {
          _lastKnownMediaInfo = info;
        }
      }

      state = state.copyWith(
        elapsedSeconds: elapsed,
        checkIntervalRemainingSeconds: remaining,
        phase: SessionPhase.monitoring,
        statusText: 'Monitoring...',
      );

      if (elapsed % 10 == 0) {
        final minsLeft = (remaining / 60).ceil();
        await ForegroundTaskService.instance.updateNotification(
          title: 'SleepStop • Phone Fade & Shake Mode',
          text: 'Audio fade check in $minsLeft min',
        );
        await _mediaControl.updateQuickTileState(
          isActive: true,
          subtitle: 'Actif • Check ${minsLeft}m',
        );
      }

      if (remaining <= 0) {
        await _startPhone60sFadeSequence();
      }
    });
  }

  Future<void> _startPhone60sFadeSequence() async {
    if (!state.isRunning || state.isFading || _isStoppingOrCompleting) return;

    _fadeStartedAt = DateTime.now();
    final currentMedia = await _mediaControl.getActiveMediaInfo();
    if (currentMedia.hasData) {
      _lastKnownMediaInfo = currentMedia;
    }

    state = state.copyWith(
      phase: SessionPhase.fadingAudio,
      isFading: true,
      fadeTotalSeconds: 60,
      fadeRemainingSeconds: 60,
      statusText: 'Fading audio...',
      detailText: 'Nudge or shake phone now to restore volume & reset timer',
    );

    await ForegroundTaskService.instance.updateNotification(
      title: 'SleepStop • Fading Audio (60s)',
      text: 'Nudge or shake your phone to keep listening!',
    );

    final completedUninterrupted = await _mediaControl.startVolumeFadeOut(
      durationSeconds: 60,
      onProgress: (remaining, currentVol, originalVol, maxVol) {
        if (!state.isRunning || !state.isFading) return;
        state = state.copyWith(
          elapsedSeconds: state.elapsedSeconds + 1,
          fadeRemainingSeconds: remaining,
          currentVolume: currentVol,
          originalVolume: originalVol,
          maxVolume: maxVol,
          statusText: 'Fading audio (${remaining}s)...',
        );
      },
    );

    if (!completedUninterrupted || !state.isRunning) {
      return;
    }

    _isStoppingOrCompleting = true;
    _sessionTicker?.cancel();
    _motionService.stopMonitoring();

    final settings = ref.read(settingsProvider);

    await _mediaControl.pauseAndRestoreVolumeAfterDelay(
      rewindBeforePause: settings.rewindOnPause,
    );

    List<String> closedAppsList = const [];
    if (settings.closeAppsOnSleep) {
      closedAppsList = await _mediaControl.closeTargetApps(
        packages: settings.targetAppsToClose.keys.toList(),
        goHome: settings.returnToHomeOnSleep,
      );
    }

    await ForegroundTaskService.instance.stopMonitoringService();
    await _mediaControl.updateQuickTileState(
      isActive: false,
      subtitle: 'Sommeil détecté • Pause',
    );

    final startTime = state.sessionStartTime ?? DateTime.now();
    final asleepTime = _fadeStartedAt ?? DateTime.now();
    final pausedAtTime = DateTime.now();
    final listeningSeconds = asleepTime
        .difference(startTime)
        .inSeconds
        .clamp(1, 86400);

    final log = SleepSessionLog(
      id: pausedAtTime.millisecondsSinceEpoch.toString(),
      mode: DetectionMode.phoneFadeShake,
      startTime: startTime,
      asleepTime: asleepTime,
      pausedAtTime: pausedAtTime,
      listeningDurationSeconds: listeningSeconds,
      triggerReason: 'No response to volume fade',
      mediaAppName:
          _lastKnownMediaInfo?.appName ??
          (closedAppsList.isNotEmpty ? closedAppsList.join(', ') : null),
      mediaTitle: _lastKnownMediaInfo?.mediaTitle,
      closedApps: closedAppsList,
    );

    await ref.read(sessionLogsProvider.notifier).addSessionLog(log);
    await NotificationService.instance.showSleepSummaryNotification(log);

    state = state.copyWith(
      isRunning: false,
      isFading: false,
      phase: SessionPhase.pausedCompleted,
      statusText: 'Sleep detected • Media paused',
      detailText:
          'No response to 60s fade. Logged asleep time at fade start & restored volume.',
    );
    _isStoppingOrCompleting = false;
  }

  Future<void> _handlePhoneMovementDetected({
    required double peakMagnitude,
  }) async {
    if (!state.isRunning || state.activeMode != DetectionMode.phoneFadeShake) {
      return;
    }

    final settings = ref.read(settingsProvider);
    final resetSeconds = settings.checkIntervalMinutes * 60;

    if (state.isFading) {
      await _mediaControl.cancelFadeAndRestoreVolume();
      final restoredVol = await _mediaControl.getCurrentVolume();
      _fadeStartedAt = null;

      state = state.copyWith(
        phase: SessionPhase.monitoring,
        isFading: false,
        fadeRemainingSeconds: 0,
        checkIntervalRemainingSeconds: resetSeconds,
        checkIntervalTotalSeconds: resetSeconds,
        currentVolume: restoredVol,
        shakeResetCount: state.shakeResetCount + 1,
        statusText: 'Monitoring...',
        detailText:
            'Movement detected (${peakMagnitude.toStringAsFixed(1)} m/s²) • Volume restored & timer reset!',
      );

      await ForegroundTaskService.instance.updateNotification(
        title: 'SleepStop • Movement Detected!',
        text:
            'Volume restored. Countdown reset to ${settings.checkIntervalMinutes} min.',
      );
    } else {
      state = state.copyWith(
        checkIntervalRemainingSeconds: resetSeconds,
        checkIntervalTotalSeconds: resetSeconds,
        detailText:
            'Motion detected (${peakMagnitude.toStringAsFixed(1)} m/s²) • Timer reset to ${settings.checkIntervalMinutes}m',
      );
    }
  }

  Future<void> triggerManualWakeReset() async {
    await _handlePhoneMovementDetected(
      peakMagnitude: ref.read(settingsProvider).shakeSensitivity + 1.0,
    );
  }

  Future<void> triggerFadeNowForTesting() async {
    if (!state.isRunning) return;
    if (state.activeMode == DetectionMode.phoneFadeShake && !state.isFading) {
      await _startPhone60sFadeSequence();
    } else if (state.activeMode == DetectionMode.watchBle && !state.isFading) {
      final threshold =
          state.effectiveThresholdBpm ??
          ref.read(settingsProvider).sleepBpmThreshold;
      await _triggerWatchSleepDetected(
        finalBpm: state.currentBpm ?? (threshold - 2),
        threshold: threshold,
        isSmartAdaptive:
            ref.read(settingsProvider).biometricTriggerMode ==
            BiometricTriggerMode.smartAdaptive,
        stdDevBpm: state.bpmStabilityStdDev,
      );
    }
  }

  Future<void> stopSession({String reason = 'Session stopped by user'}) async {
    _isStoppingOrCompleting = true;
    _sessionTicker?.cancel();
    _sessionTicker = null;
    _simulatedHrTimer?.cancel();
    _simulatedHrTimer = null;

    await _packetSubscription?.cancel();
    _packetSubscription = null;

    _motionService.stopMonitoring();
    await _mediaControl.cancelFadeAndRestoreVolume();
    await _bleService.disconnect();
    await ForegroundTaskService.instance.stopMonitoringService();
    await _mediaControl.updateQuickTileState(
      isActive: false,
      subtitle: 'Prêt à veiller',
    );

    state = ActiveSessionState(
      isRunning: false,
      phase: SessionPhase.idle,
      activeMode: state.activeMode,
      statusText: 'Ready to start sleep session',
      detailText: reason,
    );
    _isStoppingOrCompleting = false;
  }
}
