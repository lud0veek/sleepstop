import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

class MotionDetectorService {
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  DateTime _lastTriggerTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Computes linear 3D acceleration vector magnitude in m/s²:
  /// sqrt(x^2 + y^2 + z^2)
  static double calculateMagnitude(double x, double y, double z) {
    return math.sqrt((x * x) + (y * y) + (z * z));
  }

  /// Starts listening to `userAccelerometerEventStream()` (which excludes gravity)
  /// and invokes [onShakeDetected] whenever movement exceeds [threshold] (m/s²).
  void startMonitoring({
    required double threshold,
    required void Function(double magnitude) onMagnitudeUpdate,
    required void Function(double peakMagnitude) onShakeDetected,
  }) {
    stopMonitoring();

    _accelSubscription =
        userAccelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen(
          (UserAccelerometerEvent event) {
            final magnitude = calculateMagnitude(event.x, event.y, event.z);
            onMagnitudeUpdate(magnitude);

            if (magnitude >= threshold) {
              final now = DateTime.now();
              // Debounce consecutive triggers within 1200ms
              if (now.difference(_lastTriggerTime).inMilliseconds >= 1200) {
                _lastTriggerTime = now;
                onShakeDetected(magnitude);
              }
            }
          },
          onError: (_) {
            // Gracefully handle devices/emulators without user accelerometer sensor
          },
          cancelOnError: false,
        );
  }

  void stopMonitoring() {
    _accelSubscription?.cancel();
    _accelSubscription = null;
  }

  void dispose() {
    stopMonitoring();
  }
}
