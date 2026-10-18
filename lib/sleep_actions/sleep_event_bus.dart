import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sleep_settings.dart';

/// Emitted once per night, when sleep is confirmed: after the audio fade,
/// the pause and the "still awake?" grace window have all completed.
class SleepDetectedEvent {
  final DateTime timestamp;
  final DetectionMode mode;

  /// Who produced the event: `session` for a real night, `test` for the
  /// "test now" buttons in the settings screen.
  final String source;

  const SleepDetectedEvent({
    required this.timestamp,
    required this.mode,
    this.source = 'session',
  });
}

/// Minimal broadcast bus. `emit` never throws and never awaits subscribers,
/// so a misbehaving listener can never delay or break the audio pipeline.
class SleepEventBus {
  final StreamController<SleepDetectedEvent> _controller =
      StreamController<SleepDetectedEvent>.broadcast();

  Stream<SleepDetectedEvent> get events => _controller.stream;

  void emit(SleepDetectedEvent event) {
    if (_controller.isClosed) return;
    try {
      _controller.add(event);
    } catch (_) {
      // Never let a listener failure surface here.
    }
  }

  Future<void> dispose() => _controller.close();
}

final sleepEventBusProvider = Provider<SleepEventBus>((ref) {
  final bus = SleepEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});
