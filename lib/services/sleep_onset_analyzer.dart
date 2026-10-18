import 'dart:math' as math;

/// Pure-Dart building blocks of the Smart Adaptive sleep-onset detection.
/// No Flutter, no I/O: everything here is unit-testable.

/// Learns the user's *awake, resting in bed* heart rate at the start of a
/// session.
///
/// Instead of a fixed 90 s window (which is inflated by the movement of
/// settling into bed), the calibrator looks at rolling 60 s windows and keeps
/// the **lowest stable plateau** seen. It completes early once three
/// consecutive stable windows agree, and never later than [maxSeconds].
class BaselineCalibrator {
  BaselineCalibrator({
    this.minSeconds = 120,
    this.maxSeconds = 300,
    this.windowSeconds = 60,
    this.evalEverySeconds = 30,
    this.maxStdDevBpm = 3.0,
    this.agreementBpm = 2.0,
    this.minSamplesPerWindow = 20,
  });

  final int minSeconds;
  final int maxSeconds;
  final int windowSeconds;
  final int evalEverySeconds;
  final double maxStdDevBpm;
  final double agreementBpm;
  final int minSamplesPerWindow;

  final List<_Sample> _samples = [];
  final List<double> _rmssdSamples = [];

  /// One entry per evaluation; `null` means the window was not stable.
  final List<double?> _evaluations = [];

  double? _lowestStableMean;
  bool _complete = false;
  double? _finalBaseline;

  bool get isComplete => _complete;

  /// The baseline once calibration is complete, else null.
  double? get baselineBpm => _finalBaseline;

  /// Best estimate so far (for display while calibrating).
  double? get provisionalBaselineBpm =>
      _finalBaseline ?? _lowestStableMean ?? _medianBpm();

  /// Median RMSSD observed during calibration (null if no R-R data).
  double? get baselineRmssd {
    if (_rmssdSamples.length < 5) return null;
    final sorted = List<double>.from(_rmssdSamples)..sort();
    return sorted[sorted.length ~/ 2];
  }

  int get stableWindowCount => _evaluations.whereType<double>().length;

  /// Rough remaining-seconds estimate for the UI.
  int secondsLeft(int elapsedSeconds) {
    if (_complete) return 0;
    final target = elapsedSeconds < minSeconds ? minSeconds : maxSeconds;
    return (target - elapsedSeconds).clamp(0, maxSeconds);
  }

  double progress(int elapsedSeconds) {
    if (_complete) return 1.0;
    return (elapsedSeconds / minSeconds).clamp(0.0, 0.95);
  }

  void addSample({
    required int elapsedSeconds,
    required int bpm,
    double? rmssdMs,
  }) {
    if (_complete) return;
    _samples.add(_Sample(elapsedSeconds, bpm));
    if (rmssdMs != null && rmssdMs > 0) _rmssdSamples.add(rmssdMs);
  }

  /// Call once per elapsed second (from the session ticker).
  void tick(int elapsedSeconds) {
    if (_complete) return;

    if (elapsedSeconds >= windowSeconds &&
        elapsedSeconds % evalEverySeconds == 0) {
      _evaluateWindow(elapsedSeconds);
      if (elapsedSeconds >= minSeconds && _lastThreeAgree()) {
        _finish();
        return;
      }
    }

    if (elapsedSeconds >= maxSeconds) {
      _finish();
    }
  }

  void _evaluateWindow(int elapsedSeconds) {
    final from = elapsedSeconds - windowSeconds;
    final window = _samples.where((s) => s.t > from).map((s) => s.bpm).toList();
    if (window.length < minSamplesPerWindow) {
      _evaluations.add(null);
      return;
    }
    final mean = window.fold<int>(0, (a, b) => a + b) / window.length;
    final variance =
        window.fold<double>(0, (sum, v) => sum + (v - mean) * (v - mean)) /
        window.length;
    final std = math.sqrt(variance);
    if (std <= maxStdDevBpm) {
      _evaluations.add(mean);
      _lowestStableMean = _lowestStableMean == null
          ? mean
          : math.min(_lowestStableMean!, mean);
    } else {
      _evaluations.add(null);
    }
  }

  bool _lastThreeAgree() {
    if (_evaluations.length < 3) return false;
    final last = _evaluations.sublist(_evaluations.length - 3);
    if (last.any((e) => e == null)) return false;
    final values = last.cast<double>();
    final hi = values.reduce(math.max);
    final lo = values.reduce(math.min);
    return hi - lo <= agreementBpm;
  }

  double? _medianBpm() {
    if (_samples.isEmpty) return null;
    final sorted = _samples.map((s) => s.bpm).toList()..sort();
    return sorted[sorted.length ~/ 2].toDouble();
  }

  void _finish() {
    _complete = true;
    _finalBaseline = _lowestStableMean ?? _medianBpm();
  }
}

class _Sample {
  final int t;
  final int bpm;
  const _Sample(this.t, this.bpm);
}

/// Result of one evaluation of the sleep-onset criteria.
class SleepMatch {
  final bool matches;

  /// Seconds of confirmation credited for this tick (1.0, or 1.5 when the
  /// HRV rise corroborates parasympathetic activation).
  final double weight;
  final bool hrvBoost;

  const SleepMatch({
    required this.matches,
    required this.weight,
    required this.hrvBoost,
  });

  static const none = SleepMatch(matches: false, weight: 0, hrvBoost: false);
}

class SleepCriteria {
  /// Minimum absolute drop (BPM) below the awake baseline for the
  /// "stable plateau" criterion.
  static const double minAbsoluteDropBpm = 4.0;

  /// Minimum relative drop (fraction of baseline) for the same criterion.
  static const double minRelativeDrop = 0.05;

  /// Std-dev ceiling that qualifies as an "ultra stable" plateau.
  static const double ultraStableStdDev = 1.2;

  /// RMSSD must rise by this factor over the calibration value to count.
  static const double hrvRiseFactor = 1.2;

  /// Smart Adaptive evaluation.
  static SleepMatch evaluateSmart({
    required int bpm,
    required int threshold,
    required double? baselineBpm,
    required double? stdDevBpm,
    required double maxAllowedStdDev,
    double? rmssdMs,
    double? baselineRmssdMs,
  }) {
    final isStable = stdDevBpm == null || stdDevBpm <= maxAllowedStdDev;
    final isUltraStable = stdDevBpm != null && stdDevBpm <= ultraStableStdDev;
    final droppedBelowTarget = bpm <= threshold;

    bool droppedFromAwake = false;
    if (baselineBpm != null) {
      final minDrop = math.max(
        minAbsoluteDropBpm,
        baselineBpm * minRelativeDrop,
      );
      droppedFromAwake = bpm <= baselineBpm - minDrop;
    }

    final matches =
        (droppedBelowTarget && isStable) || (droppedFromAwake && isUltraStable);
    if (!matches) return SleepMatch.none;

    final hrvBoost =
        rmssdMs != null &&
        baselineRmssdMs != null &&
        baselineRmssdMs > 0 &&
        rmssdMs >= baselineRmssdMs * hrvRiseFactor;

    return SleepMatch(
      matches: true,
      weight: hrvBoost ? 1.5 : 1.0,
      hrvBoost: hrvBoost,
    );
  }

  /// Fixed-threshold evaluation.
  static SleepMatch evaluateFixed({required int bpm, required int threshold}) {
    return bpm <= threshold
        ? const SleepMatch(matches: true, weight: 1.0, hrvBoost: false)
        : SleepMatch.none;
  }
}

/// Keeps a bounded, time-based BPM timeline for the night curve.
class BpmTimeline {
  BpmTimeline({this.sampleEverySeconds = 30, this.maxPoints = 600});

  final int sampleEverySeconds;
  final int maxPoints;
  final List<int> _points = [];

  List<int> get points => List.unmodifiable(_points);

  bool shouldSample(int elapsedSeconds) =>
      elapsedSeconds > 0 && elapsedSeconds % sampleEverySeconds == 0;

  void add(int bpm) {
    _points.add(bpm);
    if (_points.length > maxPoints) _points.removeAt(0);
  }

  /// Appends a final value if it differs from the last point.
  void finish(int bpm) {
    if (_points.isEmpty || _points.last != bpm) add(bpm);
  }

  void clear() => _points.clear();
}
