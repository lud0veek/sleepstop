import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_stop/services/sleep_onset_analyzer.dart';

void main() {
  group('BaselineCalibrator', () {
    BaselineCalibrator run(List<int> Function(int t) bpmAt, {int until = 300}) {
      final c = BaselineCalibrator();
      for (int t = 1; t <= until && !c.isComplete; t++) {
        for (final bpm in bpmAt(t)) {
          c.addSample(elapsedSeconds: t, bpm: bpm);
        }
        c.tick(t);
      }
      return c;
    }

    test('a movement spike while settling does not inflate the baseline', () {
      // First 70 s: settling into bed, HR 78-84. Then calm awake at ~62.
      final c = run((t) => [t <= 70 ? 78 + (t % 7) : 62 + (t % 3 == 0 ? 1 : 0)]);
      expect(c.isComplete, isTrue);
      expect(c.baselineBpm, isNotNull);
      expect(c.baselineBpm!, lessThan(65));
      expect(c.baselineBpm!, greaterThan(60));
    });

    test('completes early (around 2 min) when the plateau is stable', () {
      int completedAt = -1;
      final c = BaselineCalibrator();
      for (int t = 1; t <= 300; t++) {
        c.addSample(elapsedSeconds: t, bpm: 60 + (t % 2));
        c.tick(t);
        if (c.isComplete) {
          completedAt = t;
          break;
        }
      }
      expect(completedAt, inInclusiveRange(120, 150));
      expect(c.baselineBpm, closeTo(60.5, 1.0));
    });

    test('falls back to the median at 5 min when HR never stabilizes', () {
      final c = run((t) => [55 + (t * 7) % 23]); // noisy, std > 3
      expect(c.isComplete, isTrue);
      expect(c.stableWindowCount, 0);
      expect(c.baselineBpm, isNotNull);
    });

    test('ignores samples once complete', () {
      final c = run((t) => [60]);
      final before = c.baselineBpm;
      c.addSample(elapsedSeconds: 999, bpm: 120);
      c.tick(999);
      expect(c.baselineBpm, before);
    });
  });

  group('SleepCriteria.evaluateSmart', () {
    test('a 2 BPM dip with a very stable pulse is NOT sleep anymore', () {
      final m = SleepCriteria.evaluateSmart(
        bpm: 62,
        threshold: 56,
        baselineBpm: 64,
        stdDevBpm: 0.8,
        maxAllowedStdDev: 1.9,
      );
      expect(m.matches, isFalse);
    });

    test('a drop of >= max(4 BPM, 5%) with an ultra-stable plateau matches', () {
      final m = SleepCriteria.evaluateSmart(
        bpm: 59,
        threshold: 55,
        baselineBpm: 64,
        stdDevBpm: 1.0,
        maxAllowedStdDev: 1.9,
      );
      expect(m.matches, isTrue);
      expect(m.weight, 1.0);
    });

    test('crossing the threshold with a stable pulse matches', () {
      final m = SleepCriteria.evaluateSmart(
        bpm: 55,
        threshold: 56,
        baselineBpm: 66,
        stdDevBpm: 1.7,
        maxAllowedStdDev: 1.9,
      );
      expect(m.matches, isTrue);
    });

    test('crossing the threshold with an unstable pulse does not match', () {
      final m = SleepCriteria.evaluateSmart(
        bpm: 55,
        threshold: 56,
        baselineBpm: 66,
        stdDevBpm: 3.2,
        maxAllowedStdDev: 1.9,
      );
      expect(m.matches, isFalse);
    });

    test('HRV rise of >= 20% over calibration boosts the weight to 1.5', () {
      final m = SleepCriteria.evaluateSmart(
        bpm: 55,
        threshold: 56,
        baselineBpm: 66,
        stdDevBpm: 1.0,
        maxAllowedStdDev: 1.9,
        rmssdMs: 40,
        baselineRmssdMs: 30,
      );
      expect(m.hrvBoost, isTrue);
      expect(m.weight, 1.5);
    });

    test('HRV never triggers on its own', () {
      final m = SleepCriteria.evaluateSmart(
        bpm: 70,
        threshold: 56,
        baselineBpm: 66,
        stdDevBpm: 1.0,
        maxAllowedStdDev: 1.9,
        rmssdMs: 80,
        baselineRmssdMs: 30,
      );
      expect(m.matches, isFalse);
    });
  });

  group('BpmTimeline', () {
    test('samples every 30 s and keeps up to 600 points (5 h)', () {
      final tl = BpmTimeline();
      int added = 0;
      for (int t = 1; t <= 30000; t++) {
        if (tl.shouldSample(t)) {
          tl.add(60);
          added++;
        }
      }
      expect(added, 1000);
      expect(tl.points.length, 600);
    });

    test('finish appends the final value only if different', () {
      final tl = BpmTimeline();
      tl.add(60);
      tl.finish(60);
      expect(tl.points.length, 1);
      tl.finish(54);
      expect(tl.points, [60, 54]);
    });
  });
}
