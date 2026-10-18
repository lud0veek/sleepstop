import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_stop/models/sleep_settings.dart';
import 'package:sleep_stop/sleep_actions/sleep_action.dart';
import 'package:sleep_stop/sleep_actions/sleep_action_dispatcher.dart';
import 'package:sleep_stop/sleep_actions/sleep_action_status.dart';
import 'package:sleep_stop/sleep_actions/sleep_event_bus.dart';

class FakeAction implements SleepAction {
  @override
  final String id;
  final bool enabledFlag;
  final Duration delay;
  final Object? throwOnExecute;
  final bool hangForever;

  int executions = 0;
  int cancels = 0;
  DateTime? startedAt;
  DateTime? finishedAt;

  FakeAction(
    this.id, {
    this.enabledFlag = true,
    this.delay = Duration.zero,
    this.throwOnExecute,
    this.hangForever = false,
  });

  @override
  bool isEnabled(SleepSettings settings) => enabledFlag;

  @override
  Future<void> execute(SleepActionContext context) async {
    executions++;
    startedAt = DateTime.now();
    if (throwOnExecute != null) throw throwOnExecute!;
    if (hangForever) {
      await Completer<void>().future;
    }
    await Future<void>.delayed(delay);
    finishedAt = DateTime.now();
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

SleepSettings settingsWith({bool master = true}) => SleepSettings(
  sleepActions: SleepActionsSettings(enabled: master),
);

SleepDetectedEvent event() => SleepDetectedEvent(
  timestamp: DateTime(2026, 10, 18, 23, 30),
  mode: DetectionMode.watchBle,
);

void main() {
  group('SleepActionDispatcher', () {
    test('runs enabled actions in parallel, not sequentially', () async {
      final a = FakeAction('a', delay: const Duration(milliseconds: 120));
      final b = FakeAction('b', delay: const Duration(milliseconds: 120));
      final d = SleepActionDispatcher(
        actions: [a, b],
        readSettings: settingsWith,
      );
      final sw = Stopwatch()..start();
      await d.dispatch(event());
      sw.stop();
      expect(a.executions, 1);
      expect(b.executions, 1);
      // Sequential would take >= 240 ms.
      expect(sw.elapsedMilliseconds, lessThan(220));
    });

    test('a throwing action never blocks the others', () async {
      final bad = FakeAction('bad', throwOnExecute: StateError('boom'));
      final good = FakeAction('good');
      final statuses = <String, SleepActionStatus>{};
      final d = SleepActionDispatcher(
        actions: [bad, good],
        readSettings: settingsWith,
        onStatus: (id, st) => statuses[id] = st,
      );
      await d.dispatch(event());
      expect(good.executions, 1);
      expect(statuses['bad']!.outcome, SleepActionOutcome.failed);
      expect(statuses['bad']!.message, contains('boom'));
      expect(statuses['good']!.outcome, SleepActionOutcome.success);
    });

    test('a hanging action is timed out and cancelled, others succeed', () async {
      final hang = FakeAction('hang', hangForever: true);
      final good = FakeAction('good');
      final statuses = <String, SleepActionStatus>{};
      final d = SleepActionDispatcher(
        actions: [hang, good],
        readSettings: settingsWith,
        timeout: const Duration(milliseconds: 100),
        onStatus: (id, st) => statuses[id] = st,
      );
      await d.dispatch(event());
      expect(statuses['hang']!.outcome, SleepActionOutcome.timedOut);
      expect(hang.cancels, 1);
      expect(statuses['good']!.outcome, SleepActionOutcome.success);
    });

    test('respects the per-action toggle', () async {
      final on = FakeAction('on', enabledFlag: true);
      final off = FakeAction('off', enabledFlag: false);
      final statuses = <String, SleepActionStatus>{};
      final d = SleepActionDispatcher(
        actions: [on, off],
        readSettings: settingsWith,
        onStatus: (id, st) => statuses[id] = st,
      );
      await d.dispatch(event());
      expect(on.executions, 1);
      expect(off.executions, 0);
      expect(statuses['off']!.outcome, SleepActionOutcome.skipped);
    });

    test('master switch off = nothing runs, even enabled actions', () async {
      final a = FakeAction('a');
      final d = SleepActionDispatcher(
        actions: [a],
        readSettings: () => settingsWith(master: false),
      );
      await d.dispatch(event());
      expect(a.executions, 0);
    });

    test('runSingle ignores the toggles (test button)', () async {
      final a = FakeAction('a', enabledFlag: false);
      final d = SleepActionDispatcher(
        actions: [a],
        readSettings: () => settingsWith(master: false),
      );
      final st = await d.runSingle('a', event());
      expect(a.executions, 1);
      expect(st.outcome, SleepActionOutcome.success);
    });

    test('dispatch never throws, even with an empty action list', () async {
      final d = SleepActionDispatcher(actions: const [], readSettings: settingsWith);
      await expectLater(d.dispatch(event()), completes);
    });
  });

  group('SleepEventBus', () {
    test('emit is fire-and-forget: no listener, after dispose, with listener',
        () async {
      final bus = SleepEventBus();
      // No listener yet: nothing to deliver, nothing thrown.
      expect(() => bus.emit(event()), returnsNormally);

      var received = 0;
      final sub = bus.events.listen((_) => received++);
      bus.emit(event());
      await Future<void>.delayed(Duration.zero);
      expect(received, 1);

      await sub.cancel();
      await bus.dispose();
      // Closed bus: emit is a no-op, never throws.
      expect(() => bus.emit(event()), returnsNormally);
    });
  });

  group('SleepActionsSettings', () {
    test('round-trips through JSON and defaults to all off', () {
      const fresh = SleepSettings();
      expect(fresh.sleepActions.enabled, isFalse);
      expect(fresh.sleepActions.activeCount, 0);

      final configured = fresh.copyWith(
        sleepActions: const SleepActionsSettings(
          enabled: true,
          lights: LightsActionSettings(
            enabled: true,
            deviceIds: ['d1'],
            roomIds: ['r1'],
            fade: LightsFadeDuration.m1,
          ),
          webhook: WebhookActionSettings(
            enabled: true,
            url: 'https://example.test/hook',
            hasSecret: true,
          ),
        ),
      );
      final back = SleepSettings.decode(configured.encode()).sleepActions;
      expect(back.enabled, isTrue);
      expect(back.activeCount, 2);
      expect(back.lights.deviceIds, ['d1']);
      expect(back.lights.fade, LightsFadeDuration.m1);
      expect(back.lights.fade.seconds, 60);
      expect(back.webhook.url, 'https://example.test/hook');
      expect(back.webhook.hasSecret, isTrue);
    });

    test('settings saved by 1.0.0+3 (no sleepActions key) still load', () {
      final s = SleepSettings.decode('{"languageCode":"de"}');
      expect(s.sleepActions.enabled, isFalse);
      expect(s.languageCode, 'de');
    });
  });
}
