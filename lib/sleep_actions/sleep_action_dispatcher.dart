import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sleep_settings.dart';
import '../providers/settings_provider.dart';
import 'actions/broadcast_intent_action.dart';
import 'sleep_action.dart';
import 'sleep_action_status.dart';
import 'sleep_event_bus.dart';

typedef StatusSink = void Function(String actionId, SleepActionStatus status);

/// Runs every enabled [SleepAction] when sleep is confirmed.
///
/// Guarantees:
/// - actions run in parallel, each in its own future;
/// - each action is bounded by [timeout] (10 s by default);
/// - an action that throws or times out never affects the others, nor the
///   audio pipeline (the bus never awaits us);
/// - the master switch and each action's own switch are read from the
///   settings at dispatch time.
class SleepActionDispatcher {
  SleepActionDispatcher({
    required List<SleepAction> actions,
    required SleepSettings Function() readSettings,
    this.timeout = const Duration(seconds: 10),
    StatusSink? onStatus,
  }) : _actions = List.unmodifiable(actions),
       _readSettings = readSettings,
       _onStatus = onStatus;

  final List<SleepAction> _actions;
  final SleepSettings Function() _readSettings;
  final StatusSink? _onStatus;
  final Duration timeout;

  final Map<String, Future<void>> _inFlight = {};

  List<SleepAction> get actions => _actions;

  /// Dispatches [event] to every enabled action. Returns when all of them
  /// have finished, failed or timed out. Never throws.
  Future<void> dispatch(SleepDetectedEvent event) async {
    final settings = _readSettings();
    final master = settings.sleepActions.enabled;
    final context = SleepActionContext(event: event, settings: settings);

    final futures = <Future<void>>[];
    for (final action in _actions) {
      if (!master || !action.isEnabled(settings)) {
        _report(action.id, const SleepActionStatus(
          outcome: SleepActionOutcome.skipped,
        ));
        continue;
      }
      futures.add(_runIsolated(action, context));
    }
    await Future.wait(futures, eagerError: false);
  }

  /// Runs one action regardless of the toggles ("test now" button).
  Future<SleepActionStatus> runSingle(String actionId, SleepDetectedEvent event) async {
    final action = _actions.firstWhere(
      (a) => a.id == actionId,
      orElse: () => throw ArgumentError('Unknown action $actionId'),
    );
    final context = SleepActionContext(event: event, settings: _readSettings());
    return _runIsolated(action, context);
  }

  /// Best-effort cancellation of everything still running.
  Future<void> cancelAll() async {
    for (final action in _actions) {
      try {
        await action.cancel();
      } catch (_) {}
    }
  }

  Future<SleepActionStatus> _runIsolated(
    SleepAction action,
    SleepActionContext context,
  ) async {
    final id = action.id;
    if (_inFlight.containsKey(id)) {
      // Already running (e.g. test button pressed twice): leave it alone.
      return const SleepActionStatus(
        outcome: SleepActionOutcome.running,
        message: 'already running',
      );
    }
    _report(id, SleepActionStatus(
      outcome: SleepActionOutcome.running,
      at: DateTime.now(),
    ));

    final completer = Completer<SleepActionStatus>();
    final run = () async {
      SleepActionStatus status;
      try {
        await action.execute(context).timeout(timeout);
        status = SleepActionStatus(
          outcome: SleepActionOutcome.success,
          at: DateTime.now(),
        );
      } on TimeoutException {
        try {
          await action.cancel();
        } catch (_) {}
        status = SleepActionStatus(
          outcome: SleepActionOutcome.timedOut,
          message: 'timeout ${timeout.inSeconds}s',
          at: DateTime.now(),
        );
      } catch (e) {
        status = SleepActionStatus(
          outcome: SleepActionOutcome.failed,
          message: _safeMessage(e),
          at: DateTime.now(),
        );
      }
      _report(id, status);
      if (!completer.isCompleted) completer.complete(status);
    }();
    _inFlight[id] = run;
    try {
      return await completer.future;
    } finally {
      _inFlight.remove(id);
    }
  }

  void _report(String id, SleepActionStatus status) {
    try {
      _onStatus?.call(id, status);
    } catch (_) {}
  }

  /// Error text kept short and free of URLs / identifiers in release builds.
  static String _safeMessage(Object error) {
    final raw = error.toString();
    if (kReleaseMode) {
      return raw.split(':').first.trim();
    }
    return raw.length > 160 ? '${raw.substring(0, 160)}…' : raw;
  }
}

// ---------------------------------------------------------------------------
// Riverpod wiring
// ---------------------------------------------------------------------------

/// Last status per action id, for the settings screen.
final sleepActionStatusesProvider =
    NotifierProvider<SleepActionStatusesNotifier, Map<String, SleepActionStatus>>(
      SleepActionStatusesNotifier.new,
    );

class SleepActionStatusesNotifier
    extends Notifier<Map<String, SleepActionStatus>> {
  @override
  Map<String, SleepActionStatus> build() => const {};

  void set(String id, SleepActionStatus status) {
    state = {...state, id: status};
  }
}

/// The registered actions (webhook and lights are added by later steps).
final sleepActionsProvider = Provider<List<SleepAction>>(
  (ref) => const [BroadcastIntentAction()],
);

/// Builds the dispatcher and subscribes it to the sleep event bus. Must be
/// read once at app start (HomeScreen does it) so the subscription exists
/// before the first night.
final sleepActionDispatcherProvider = Provider<SleepActionDispatcher>((ref) {
  final dispatcher = SleepActionDispatcher(
    actions: ref.read(sleepActionsProvider),
    readSettings: () => ref.read(settingsProvider),
    onStatus: (id, status) =>
        ref.read(sleepActionStatusesProvider.notifier).set(id, status),
  );
  final sub = ref.read(sleepEventBusProvider).events.listen((event) {
    unawaited(dispatcher.dispatch(event));
  });
  ref.onDispose(sub.cancel);
  return dispatcher;
});
