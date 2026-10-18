import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../models/active_session_state.dart';
import '../models/sleep_session_log.dart';
import '../models/sleep_settings.dart';
import '../services/ble_heart_rate_service.dart';
import '../services/foreground_task_service.dart';
import '../services/media_control_service.dart';
import '../services/motion_detector_service.dart';
import '../services/notification_service.dart';
import '../services/sleep_onset_analyzer.dart';
import '../services/telemetry_service.dart';
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

/// Orchestrates a night: BLE / motion inputs, the sleep-onset decision, the
/// audio fade, the "still awake?" grace window and the final log.
class SleepSessionNotifier extends Notifier<ActiveSessionState> {
  /// No heart-rate packet for this long = the watch signal is stale.
  static const int _staleAfterSeconds = 15;

  /// Give up (without touching the media) after this long without signal.
  static const int _signalLostAbortSeconds = 600;

  /// Try to reconnect the watch every N seconds while the signal is lost.
  static const int _reconnectEverySeconds = 10;

  /// How long the user has to say "still awake" after the media is paused.
  static const int graceWindowSeconds = 90;

  /// Threshold is lowered by this much for the rest of the night after each
  /// false positive ("still awake").
  static const int _stillAwakePenaltyBpm = 2;

  late final MediaControlService _mediaControl;
  late final BleHeartRateService _bleService;
  late final MotionDetectorService _motionService;

  Timer? _sessionTicker;
  Timer? _simulatedHrTimer;
  Timer? _graceTimer;
  StreamSubscription<HeartRatePacket>? _packetSubscription;
  StreamSubscription<List<DiscoveredBleWatch>>? _watchesSubscription;
  StreamSubscription<String>? _bleStatusSubscription;

  final List<int> _rolling60sBpms = [];
  final List<int> _rollingRrIntervalsMs = [];
  final BpmTimeline _timeline = BpmTimeline();
  BaselineCalibrator? _calibrator;

  double _lowSecondsAccum = 0.0;
  int _nightThresholdPenaltyBpm = 0;
  int _stillAwakeCount = 0;
  bool _isSimulated = false;
  ActiveMediaInfo? _lastKnownMediaInfo;
  DateTime? _fadeStartedAt;
  bool _isStoppingOrCompleting = false;

  // Pending night, built when the media is paused and committed when the
  // grace window expires without a "still awake".
  _PendingNight? _pendingNight;

  /// Current UI language strings (notifications, tile, history reasons).
  AppStrings get _s => ref.read(appStringsProvider);

  @override
  ActiveSessionState build() {
    _mediaControl = ref.read(mediaControlServiceProvider);
    _bleService = ref.read(bleHeartRateServiceProvider);
    _motionService = ref.read(motionDetectorServiceProvider);

    FlutterForegroundTask.addTaskDataCallback(_onForegroundTaskData);
    _mediaControl.setNativeCallbacks(
      onQuickTileToggle: _handleQuickTileToggle,
      onStillAwake: stillAwake,
    );

    Future.microtask(() async {
      final launchedFromTile = await _mediaControl
          .consumeQuickTileLaunchTrigger();
      if (launchedFromTile && !state.isRunning) {
        await startSession();
      } else {
        await _mediaControl.updateQuickTileState(
          isActive: state.isRunning,
          subtitle: state.isRunning ? _s.tileActive : _s.tileReady,
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
      _graceTimer?.cancel();
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
    if (data is! Map) return;
    switch (data['event']) {
      case 'stop_session':
        stopSession(reason: 'Stopped from notification');
      case 'still_awake':
        stillAwake();
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

  // ===========================================================================
  // Session start
  // ===========================================================================
  Future<void> startSession({bool simulateBleWatch = false}) async {
    if (state.isRunning) return;
    _isStoppingOrCompleting = false;
    _resetNightState();

    final settings = ref.read(settingsProvider);
    final mode = state.activeMode;
    final startTime = DateTime.now();
    ForegroundTaskService.instance.stopButtonLabel = _s.stopSessionButton;
    ForegroundTaskService.instance.stillAwakeButtonLabel = _s.stillAwakeButton;
    final initialVol = await _mediaControl.getCurrentVolume();
    final maxVol = await _mediaControl.getMaxVolume();
    _lastKnownMediaInfo = await _mediaControl.getActiveMediaInfo();

    unawaited(
      TelemetryService.instance.recordSessionStarted(
        enabled: settings.anonymousTelemetryEnabled,
        mode: mode,
        languageCode: settings.languageCode,
      ),
    );

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

  void _resetNightState() {
    _rolling60sBpms.clear();
    _rollingRrIntervalsMs.clear();
    _timeline.clear();
    _calibrator = null;
    _lowSecondsAccum = 0.0;
    _nightThresholdPenaltyBpm = 0;
    _stillAwakeCount = 0;
    _isSimulated = false;
    _pendingNight = null;
    _fadeStartedAt = null;
    _graceTimer?.cancel();
    _graceTimer = null;
  }

  // ===========================================================================
  // Detection Mode A: Watch (BLE heart rate)
  // ===========================================================================
  Future<void> _startWatchBleSession({
    required SleepSettings settings,
    required DateTime startTime,
    required int initialVolume,
    required int maxVolume,
    required bool simulateBleWatch,
  }) async {
    final isSmart =
        settings.biometricTriggerMode == BiometricTriggerMode.smartAdaptive;
    final requiredLowSeconds = settings.confirmationDurationMinutes * 60;
    final initialTarget = isSmart
        ? (settings.learnedSleepingBpm?.round() ?? settings.sleepBpmThreshold)
        : settings.sleepBpmThreshold;
    _isSimulated = simulateBleWatch;
    _calibrator = isSmart ? BaselineCalibrator() : null;

    state = ActiveSessionState(
      isRunning: true,
      phase: simulateBleWatch
          ? (isSmart
                ? SessionPhase.calibratingBaseline
                : SessionPhase.monitoring)
          : SessionPhase.scanningBle,
      activeMode: DetectionMode.watchBle,
      statusText: simulateBleWatch ? 'Calibrating...' : 'Connecting...',
      detailText: simulateBleWatch
          ? 'Simulated HR + R-R stream active'
          : 'Looking for your paired watch...',
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
      title: _s.fgTitleWatch,
      text: simulateBleWatch ? _s.fgSimulatedWatch : _s.fgConnectingWatch,
    );
    await _mediaControl.updateQuickTileState(
      isActive: true,
      subtitle: simulateBleWatch
          ? _s.tileSimulatedActive
          : _s.tileConnectingWatch,
    );

    if (simulateBleWatch) {
      state = state.copyWith(
        connectedWatchName: 'Simulated watch',
        connectedWatchId: 'SIM-180D',
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
        subtitle: _s.tileWatchNotFound,
      );
      state = state.copyWith(
        isRunning: false,
        phase: SessionPhase.error,
        statusText: 'No heart-rate watch found',
        detailText:
            state.detailText ??
            'Turn on "Broadcast HR" on your watch, then try again.',
      );
      return;
    }

    final watchName =
        (_bleService.resolvedWatchName != null &&
            _bleService.resolvedWatchName!.isNotEmpty)
        ? _bleService.resolvedWatchName!
        : (device.platformName.isNotEmpty
              ? device.platformName
              : 'Watch (${device.remoteId.str})');

    await ref
        .read(settingsProvider.notifier)
        .setSavedWatch(id: device.remoteId.str, name: watchName);

    state = state.copyWith(
      phase: isSmart
          ? SessionPhase.calibratingBaseline
          : SessionPhase.monitoring,
      connectedWatchName: watchName,
      connectedWatchId: device.remoteId.str,
      statusText: isSmart ? 'Calibrating...' : 'Monitoring...',
      detailText: 'Connected to $watchName',
    );
    await _mediaControl.updateQuickTileState(
      isActive: true,
      subtitle: _s.tileActiveWatch(watchName),
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
      if (tick <= 150) {
        // Awake, settling: ~64 BPM with a bit of noise.
        bpm = 64 + rng.nextInt(5) - 2;
      } else if (tick <= 210) {
        bpm = (64 - ((tick - 150) * 0.2)).round();
      } else {
        final target = math.min(settings.sleepBpmThreshold - 2, 64 - 9);
        bpm = target + (tick % 2 == 0 ? 0 : -1);
      }
      final rrMs = (60000 / bpm).round() + (tick <= 150 ? rng.nextInt(35) : 6);
      _bleService.markSimulatedPacket();
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

    return (rawTarget.round() - _nightThresholdPenaltyBpm).clamp(40, 95);
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
    int threshold = (settings.sleepBpmThreshold - _nightThresholdPenaltyBpm)
        .clamp(40, 95);

    if (isSmart) {
      final calibrator = _calibrator ??= BaselineCalibrator();
      if (!calibrator.isComplete) {
        calibrator.addSample(
          elapsedSeconds: state.elapsedSeconds,
          bpm: bpm,
          rmssdMs: rmssd,
        );
      }
      baseline = calibrator.baselineBpm ?? calibrator.provisionalBaselineBpm;
      if (baseline != null) {
        threshold = _computeSmartAdaptiveThreshold(
          awakeBaselineBpm: baseline,
          settings: settings,
        );
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
      if (!state.isRunning ||
          state.isFading ||
          state.isInGraceWindow ||
          _isStoppingOrCompleting) {
        return;
      }

      final settings = ref.read(settingsProvider);
      final isSmart =
          settings.biometricTriggerMode == BiometricTriggerMode.smartAdaptive;
      final elapsed = state.elapsedSeconds + 1;
      final requiredSeconds = settings.confirmationDurationMinutes * 60;
      final bpm = state.currentBpm;
      final threshold =
          state.effectiveThresholdBpm ?? settings.sleepBpmThreshold;
      final stdDev = state.bpmStabilityStdDev;
      final bpmLabel = bpm != null ? '$bpm BPM' : '-- BPM';

      // Refresh active media info every 15 seconds while playing
      if (elapsed % 15 == 0) {
        final info = await _mediaControl.getActiveMediaInfo();
        if (info.hasData) {
          _lastKnownMediaInfo = info;
        }
      }

      // Night curve: one point every 30 s of wall clock.
      if (bpm != null && _timeline.shouldSample(elapsed)) {
        _timeline.add(bpm);
      }

      // ---- Signal freshness -------------------------------------------------
      final sinceLast = _bleService.secondsSinceLastPacket();
      final stale =
          !_isSimulated &&
          (sinceLast ?? elapsed) > _staleAfterSeconds;

      if (stale) {
        final lostFor = state.signalLostSeconds + 1;
        if (lostFor >= _signalLostAbortSeconds) {
          await _abortForSignalLoss();
          return;
        }
        if (lostFor % _reconnectEverySeconds == 1 && !_bleService.isLinkUp) {
          unawaited(_bleService.reconnectLastDevice());
        }
        state = state.copyWith(
          elapsedSeconds: elapsed,
          phase: SessionPhase.signalLost,
          signalLostSeconds: lostFor,
          statusText: 'Signal lost...',
          bpmTimeline: _timeline.points,
        );
        if (lostFor % 5 == 1) {
          await ForegroundTaskService.instance.updateNotification(
            title: _s.fgSignalLostTitle,
            text: _s.fgSignalLostBody(lostFor),
          );
          await _mediaControl.updateQuickTileState(
            isActive: true,
            subtitle: _s.tileSignalLost,
          );
        }
        return;
      }

      final justRecovered = state.isSignalStale;
      if (justRecovered) {
        await ForegroundTaskService.instance.updateNotification(
          title: _s.fgBpmTitle(bpmLabel, threshold),
          text: _s.fgSignalBackBody,
        );
      }

      // ---- Calibration ------------------------------------------------------
      final calibrator = _calibrator;
      if (isSmart && calibrator != null && !calibrator.isComplete) {
        calibrator.tick(elapsed);
        final secsLeft = calibrator.secondsLeft(elapsed);
        state = state.copyWith(
          elapsedSeconds: elapsed,
          phase: SessionPhase.calibratingBaseline,
          signalLostSeconds: 0,
          calibrationProgress: calibrator.progress(elapsed),
          baselineBpm: calibrator.provisionalBaselineBpm,
          statusText: 'Calibrating...',
          requiredLowHrSeconds: requiredSeconds,
          bpmTimeline: _timeline.points,
        );
        if (elapsed % 10 == 0 || calibrator.isComplete) {
          await ForegroundTaskService.instance.updateNotification(
            title: _s.fgBpmTitle(bpmLabel, threshold),
            text: calibrator.isComplete
                ? _s.fgMonitoring
                : _s.fgCalibrating(secsLeft),
          );
        }
        if (!calibrator.isComplete) return;
        // Calibration just finished: lock in the baseline-derived threshold.
        final finalBaseline = calibrator.baselineBpm;
        if (finalBaseline != null) {
          state = state.copyWith(
            baselineBpm: finalBaseline,
            calibrationProgress: 1.0,
            effectiveThresholdBpm: _computeSmartAdaptiveThreshold(
              awakeBaselineBpm: finalBaseline,
              settings: settings,
            ),
          );
        }
        return;
      }

      // ---- Sleep-onset criteria --------------------------------------------
      SleepMatch match = SleepMatch.none;
      if (bpm != null) {
        if (isSmart) {
          final maxAllowedStdDev = switch (settings.adaptiveSensitivity) {
            AdaptiveSensitivity.fast => 2.4,
            AdaptiveSensitivity.balanced => 1.9,
            AdaptiveSensitivity.deep => 1.5,
          };
          match = SleepCriteria.evaluateSmart(
            bpm: bpm,
            threshold: threshold,
            baselineBpm: state.baselineBpm,
            stdDevBpm: stdDev,
            maxAllowedStdDev: maxAllowedStdDev,
            rmssdMs: state.hrvRmssdMs,
            baselineRmssdMs: calibrator?.baselineRmssd,
          );
        } else {
          match = SleepCriteria.evaluateFixed(bpm: bpm, threshold: threshold);
        }
      }

      if (match.matches) {
        _lowSecondsAccum = math.min(
          _lowSecondsAccum + match.weight,
          requiredSeconds.toDouble(),
        );
      } else {
        _lowSecondsAccum = isSmart
            ? math.max(0.0, _lowSecondsAccum - 2.0)
            : 0.0;
      }
      final lowSeconds = _lowSecondsAccum.floor().clamp(0, requiredSeconds);

      final SessionPhase phase;
      if (match.matches) {
        phase = SessionPhase.hrDropping;
      } else {
        phase = lowSeconds > 0
            ? SessionPhase.hrDropping
            : SessionPhase.monitoring;
      }

      final confidence = (lowSeconds / requiredSeconds).clamp(0.0, 1.0);

      state = state.copyWith(
        elapsedSeconds: elapsed,
        consecutiveLowHrSeconds: lowSeconds,
        requiredLowHrSeconds: requiredSeconds,
        sleepConfidenceScore: confidence,
        phase: phase,
        signalLostSeconds: 0,
        statusText: match.matches ? 'Sleep onset...' : 'Monitoring...',
        bpmTimeline: _timeline.points,
      );

      if (elapsed % 5 == 0 && !justRecovered) {
        final String notifText;
        if (match.matches) {
          final currentMin = ((lowSeconds ~/ 60) + 1).clamp(
            1,
            settings.confirmationDurationMinutes,
          );
          notifText = _s.fgSleepOnset(
            currentMin,
            settings.confirmationDurationMinutes,
          );
        } else if (lowSeconds > 0) {
          notifText = _s.fgStabilizing;
        } else {
          notifText = _s.fgMonitoring;
        }
        await ForegroundTaskService.instance.updateNotification(
          title: _s.fgBpmTitle(bpmLabel, threshold),
          text: notifText,
        );
        await _mediaControl.updateQuickTileState(
          isActive: true,
          subtitle: _s.tileActiveBpm(bpmLabel, threshold),
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

  Future<void> _abortForSignalLoss() async {
    _isStoppingOrCompleting = true;
    _sessionTicker?.cancel();
    _sessionTicker = null;
    await _packetSubscription?.cancel();
    _packetSubscription = null;
    await _bleService.disconnect();
    await ForegroundTaskService.instance.stopMonitoringService();
    await _mediaControl.updateQuickTileState(
      isActive: false,
      subtitle: _s.tileWatchNotFound,
    );
    state = state.copyWith(
      isRunning: false,
      phase: SessionPhase.error,
      statusText: 'Watch unreachable',
      detailText: _s.signalLostAbortedDetail,
    );
    _isStoppingOrCompleting = false;
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
    );

    await ForegroundTaskService.instance.updateNotification(
      title: _s.fgSleepConfirmedTitle(finalBpm),
      text: _s.fgFadingBody(10),
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

    _timeline.finish(finalBpm);

    final triggerReason = isSmartAdaptive
        ? _s.triggerReasonHr(
            finalBpm,
            baselineBpm: state.baselineBpm,
            stdDevBpm: stdDevBpm,
          )
        : _s.triggerReasonHr(finalBpm);

    _pendingNight = _PendingNight(
      mode: DetectionMode.watchBle,
      asleepTime: asleepTime,
      pausedAtTime: DateTime.now(),
      triggerReason: triggerReason,
      finalBpm: finalBpm,
      baselineBpm: state.baselineBpm,
      watchName: state.connectedWatchName,
      bpmTimeline: _timeline.points,
    );

    await _enterGraceWindow();
  }

  // ===========================================================================
  // Grace window: "still awake?"
  // ===========================================================================
  Future<void> _enterGraceWindow() async {
    _graceTimer?.cancel();
    state = state.copyWith(
      phase: SessionPhase.graceWindow,
      isFading: false,
      fadeRemainingSeconds: 0,
      graceRemainingSeconds: graceWindowSeconds,
      statusText: 'Paused • still awake?',
    );

    await ForegroundTaskService.instance.updateNotification(
      title: _s.fgGraceTitle,
      text: _s.fgGraceBody(graceWindowSeconds),
      withStillAwakeButton: true,
    );
    await _mediaControl.updateQuickTileState(
      isActive: true,
      subtitle: _s.tileGrace,
    );

    // Night veil over the media app (if the user granted the overlay
    // permission): the OLED goes black at minimum brightness right away.
    final settings = ref.read(settingsProvider);
    if (settings.returnToHomeOnSleep) {
      await _mediaControl.showNightOverlay(
        title: _s.veilTitle,
        hint: _s.veilHint,
        countdown: _s.veilCountdown(graceWindowSeconds),
      );
    }

    // A shake means "I'm awake" in both modes.
    _motionService.startMonitoring(
      threshold: settings.shakeSensitivity,
      onMagnitudeUpdate: (_) {},
      onShakeDetected: (_) => stillAwake(),
    );

    _graceTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!state.isRunning || !state.isInGraceWindow) {
        _graceTimer?.cancel();
        _graceTimer = null;
        return;
      }
      final remaining = state.graceRemainingSeconds - 1;
      state = state.copyWith(
        graceRemainingSeconds: remaining.clamp(0, graceWindowSeconds),
        elapsedSeconds: state.elapsedSeconds + 1,
      );
      if (remaining > 0 && remaining % 5 == 0) {
        await _mediaControl.updateNightOverlay(
          countdown: _s.veilCountdown(remaining),
        );
      }
      if (remaining % 15 == 0 && remaining > 0) {
        await ForegroundTaskService.instance.updateNotification(
          title: _s.fgGraceTitle,
          text: _s.fgGraceBody(remaining),
          withStillAwakeButton: true,
        );
      }
      if (remaining <= 0) {
        _graceTimer?.cancel();
        _graceTimer = null;
        await _finalizeNight();
      }
    });
  }

  /// The user says they are still awake: resume playback, forget this
  /// detection, harden the threshold for the night and keep monitoring.
  Future<void> stillAwake() async {
    if (!state.isRunning || !state.isInGraceWindow) return;
    _graceTimer?.cancel();
    _graceTimer = null;
    _motionService.stopMonitoring();
    _pendingNight = null;
    _stillAwakeCount++;
    _nightThresholdPenaltyBpm += _stillAwakePenaltyBpm;
    _lowSecondsAccum = 0.0;

    await _mediaControl.hideNightOverlay();
    await _mediaControl.resumeMedia();

    final settings = ref.read(settingsProvider);
    final isWatch = state.activeMode == DetectionMode.watchBle;
    final isSmart =
        settings.biometricTriggerMode == BiometricTriggerMode.smartAdaptive;

    final newThreshold = isWatch && isSmart && state.baselineBpm != null
        ? _computeSmartAdaptiveThreshold(
            awakeBaselineBpm: state.baselineBpm!,
            settings: settings,
          )
        : (settings.sleepBpmThreshold - _nightThresholdPenaltyBpm).clamp(
            40,
            95,
          );

    state = state.copyWith(
      phase: SessionPhase.monitoring,
      graceRemainingSeconds: 0,
      consecutiveLowHrSeconds: 0,
      sleepConfidenceScore: 0.0,
      stillAwakeCount: _stillAwakeCount,
      effectiveThresholdBpm: newThreshold,
      checkIntervalRemainingSeconds: settings.checkIntervalMinutes * 60,
      checkIntervalTotalSeconds: settings.checkIntervalMinutes * 60,
      statusText: 'Monitoring...',
      detailText: _s.stillAwakeToast,
    );

    await ForegroundTaskService.instance.updateNotification(
      title: _s.fgResumedTitle,
      text: _s.fgResumedBody,
    );
    await _mediaControl.updateQuickTileState(
      isActive: true,
      subtitle: _s.tileActive,
    );

    _isStoppingOrCompleting = false;
    if (isWatch) {
      if (_isSimulated) _startSimulatedHeartRateFeed(settings);
      _startWatchSessionTicker();
    } else {
      _fadeStartedAt = null;
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
  }

  /// Grace window expired: the user is asleep. Close apps, log the night,
  /// learn, notify, and release everything.
  Future<void> _finalizeNight() async {
    final pending = _pendingNight;
    if (pending == null) {
      await stopSession(reason: 'Session ended');
      return;
    }
    _pendingNight = null;
    _motionService.stopMonitoring();

    final settings = ref.read(settingsProvider);

    List<String> closedAppsList = const [];
    if (settings.closeAppsOnSleep || settings.returnToHomeOnSleep) {
      closedAppsList = await _mediaControl.closeTargetApps(
        packages: settings.closeAppsOnSleep
            ? settings.targetAppsToClose.keys.toList()
            : const [],
        goHome: settings.returnToHomeOnSleep,
      );
    }
    // The veil stays (without tap-to-resume) until the system switches the
    // display off; it removes itself on ACTION_SCREEN_OFF.
    await _mediaControl.finalizeNightOverlay(
      title: _s.veilGoodNight,
      hint: _s.veilGoodNightHint,
    );

    if (pending.mode == DetectionMode.watchBle) {
      await _packetSubscription?.cancel();
      _packetSubscription = null;
      _simulatedHrTimer?.cancel();
      _simulatedHrTimer = null;
      await _bleService.disconnect();
    }
    await ForegroundTaskService.instance.stopMonitoringService();
    await _mediaControl.updateQuickTileState(
      isActive: false,
      subtitle: pending.mode == DetectionMode.watchBle
          ? _s.tileSleepDetectedBpm(pending.finalBpm ?? 0)
          : _s.tileSleepDetectedPaused,
    );

    // Only learn from nights without a false positive: a corrected detection
    // must not drag the learned sleeping BPM upwards.
    if (pending.mode == DetectionMode.watchBle &&
        pending.finalBpm != null &&
        _stillAwakeCount == 0) {
      await ref
          .read(settingsProvider.notifier)
          .recordLearnedSleepingBpm(pending.finalBpm!);
    }

    final startTime = state.sessionStartTime ?? pending.asleepTime;
    final listeningSeconds = pending.asleepTime
        .difference(startTime)
        .inSeconds
        .clamp(1, 86400);

    final log = SleepSessionLog(
      id: pending.pausedAtTime.millisecondsSinceEpoch.toString(),
      mode: pending.mode,
      startTime: startTime,
      asleepTime: pending.asleepTime,
      pausedAtTime: pending.pausedAtTime,
      listeningDurationSeconds: listeningSeconds,
      triggerReason: pending.triggerReason,
      finalBpm: pending.finalBpm,
      baselineBpm: pending.baselineBpm,
      watchName: pending.watchName,
      mediaAppName:
          _lastKnownMediaInfo?.appName ??
          (closedAppsList.isNotEmpty ? closedAppsList.join(', ') : null),
      mediaTitle: _lastKnownMediaInfo?.mediaTitle,
      closedApps: closedAppsList,
      bpmTimeline: pending.bpmTimeline,
    );

    await ref.read(sessionLogsProvider.notifier).addSessionLog(log);
    await ref.read(settingsProvider.notifier).consumeTrialNight();
    await NotificationService.instance.showSleepSummaryNotification(log, _s);

    unawaited(
      TelemetryService.instance.recordSleepDetected(
        enabled: settings.anonymousTelemetryEnabled,
        mode: pending.mode,
        languageCode: settings.languageCode,
        listeningMinutes: (listeningSeconds / 60).ceil().clamp(1, 720),
        mediaAppName: log.mediaAppName,
      ),
    );

    state = state.copyWith(
      isRunning: false,
      isFading: false,
      phase: SessionPhase.pausedCompleted,
      graceRemainingSeconds: 0,
      statusText: 'Sleep detected • Media paused',
      detailText: pending.triggerReason,
    );
    _isStoppingOrCompleting = false;
  }

  // ===========================================================================
  // Detection Mode B: Phone-Only Mode ("Smart Fade & Shake")
  // ===========================================================================
  Future<void> _startPhoneFadeShakeSession({
    required SleepSettings settings,
    required DateTime startTime,
    required int initialVolume,
    required int maxVolume,
  }) async {
    final totalIntervalSeconds = settings.checkIntervalMinutes * 60;
    _fadeStartedAt = null;

    state = ActiveSessionState(
      isRunning: true,
      phase: SessionPhase.monitoring,
      activeMode: DetectionMode.phoneFadeShake,
      statusText: 'Monitoring...',
      sessionStartTime: startTime,
      elapsedSeconds: 0,
      checkIntervalRemainingSeconds: totalIntervalSeconds,
      checkIntervalTotalSeconds: totalIntervalSeconds,
      originalVolume: initialVolume,
      currentVolume: initialVolume,
      maxVolume: maxVolume,
    );

    await ForegroundTaskService.instance.startMonitoringService(
      title: _s.fgTitlePhone,
      text: _s.fgNextCheck(settings.checkIntervalMinutes),
    );
    await _mediaControl.updateQuickTileState(
      isActive: true,
      subtitle: _s.tileActiveCheck(settings.checkIntervalMinutes),
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
      if (!state.isRunning ||
          state.isFading ||
          state.isInGraceWindow ||
          _isStoppingOrCompleting) {
        return;
      }

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
          title: _s.fgTitlePhone,
          text: _s.fgNextCheck(minsLeft),
        );
        await _mediaControl.updateQuickTileState(
          isActive: true,
          subtitle: _s.tileActiveCheck(minsLeft),
        );
      }

      if (remaining <= 0) {
        await _startPhone60sFadeSequence();
      }
    });
  }

  Future<void> _startPhone60sFadeSequence() async {
    if (!state.isRunning ||
        state.isFading ||
        state.isInGraceWindow ||
        _isStoppingOrCompleting) {
      return;
    }

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
    );

    await ForegroundTaskService.instance.updateNotification(
      title: _s.fgFadingTitle60,
      text: _s.fgFadingNudge,
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

    _pendingNight = _PendingNight(
      mode: DetectionMode.phoneFadeShake,
      asleepTime: _fadeStartedAt ?? DateTime.now(),
      pausedAtTime: DateTime.now(),
      triggerReason: _s.triggerReasonFade,
    );

    await _enterGraceWindow();
  }

  Future<void> _handlePhoneMovementDetected({
    required double peakMagnitude,
  }) async {
    if (!state.isRunning || state.activeMode != DetectionMode.phoneFadeShake) {
      return;
    }
    if (state.isInGraceWindow) {
      await stillAwake();
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
      );

      await ForegroundTaskService.instance.updateNotification(
        title: _s.fgMovementTitle,
        text: _s.fgMovementBody(settings.checkIntervalMinutes),
      );
    } else {
      state = state.copyWith(
        checkIntervalRemainingSeconds: resetSeconds,
        checkIntervalTotalSeconds: resetSeconds,
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
    _graceTimer?.cancel();
    _graceTimer = null;
    _pendingNight = null;

    await _packetSubscription?.cancel();
    _packetSubscription = null;

    _motionService.stopMonitoring();
    await _mediaControl.hideNightOverlay();
    await _mediaControl.cancelFadeAndRestoreVolume();
    await _bleService.disconnect();
    await ForegroundTaskService.instance.stopMonitoringService();
    await _mediaControl.updateQuickTileState(
      isActive: false,
      subtitle: _s.tileReady,
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

/// Everything needed to write the night's log once the grace window expires.
class _PendingNight {
  final DetectionMode mode;
  final DateTime asleepTime;
  final DateTime pausedAtTime;
  final String triggerReason;
  final int? finalBpm;
  final double? baselineBpm;
  final String? watchName;
  final List<int> bpmTimeline;

  const _PendingNight({
    required this.mode,
    required this.asleepTime,
    required this.pausedAtTime,
    required this.triggerReason,
    this.finalBpm,
    this.baselineBpm,
    this.watchName,
    this.bpmTimeline = const [],
  });
}
