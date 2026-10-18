enum SleepActionOutcome { idle, skipped, running, success, failed, timedOut }

/// Last known result of one action, shown in the "When I fall asleep" screen.
class SleepActionStatus {
  final SleepActionOutcome outcome;
  final String? message;
  final DateTime? at;

  const SleepActionStatus({
    this.outcome = SleepActionOutcome.idle,
    this.message,
    this.at,
  });

  static const idle = SleepActionStatus();

  SleepActionStatus copyWith({
    SleepActionOutcome? outcome,
    String? message,
    bool clearMessage = false,
    DateTime? at,
  }) {
    return SleepActionStatus(
      outcome: outcome ?? this.outcome,
      message: clearMessage ? null : (message ?? this.message),
      at: at ?? this.at,
    );
  }

  @override
  String toString() => 'SleepActionStatus($outcome, $message, $at)';
}
