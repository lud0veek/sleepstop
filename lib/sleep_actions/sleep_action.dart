import '../models/sleep_settings.dart';
import 'sleep_event_bus.dart';

/// What an action receives when it runs.
class SleepActionContext {
  final SleepDetectedEvent event;
  final SleepSettings settings;

  const SleepActionContext({required this.event, required this.settings});
}

/// One thing to do when sleep is confirmed (lights off, broadcast, webhook…).
///
/// Contract:
/// - [execute] may throw; the dispatcher isolates it and records the failure.
/// - [execute] must be cancellable through [cancel]; cancel is best-effort and
///   must never throw.
/// - [isEnabled] is read from the persisted settings on every event, so a
///   toggle flipped during the night is honoured without restart.
abstract class SleepAction {
  String get id;

  bool isEnabled(SleepSettings settings);

  Future<void> execute(SleepActionContext context);

  Future<void> cancel();
}
