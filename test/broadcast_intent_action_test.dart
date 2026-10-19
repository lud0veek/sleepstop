import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_stop/app_info.dart';
import 'package:sleep_stop/models/sleep_settings.dart';
import 'package:sleep_stop/sleep_actions/actions/broadcast_intent_action.dart';
import 'package:sleep_stop/sleep_actions/sleep_action.dart';
import 'package:sleep_stop/sleep_actions/sleep_event_bus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.sleepstop/home_actions');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  SleepActionContext ctx({String source = 'session'}) => SleepActionContext(
    event: SleepDetectedEvent(
      timestamp: DateTime.fromMillisecondsSinceEpoch(1760000000000),
      mode: DetectionMode.watchBle,
      source: source,
    ),
    settings: const SleepSettings(),
  );

  test('sends the broadcast with the documented action and extras', () async {
    const action = BroadcastIntentAction(channel: channel);
    await action.execute(ctx());
    expect(calls, hasLength(1));
    expect(calls.single.method, 'sendSleepBroadcast');
    final args = Map<String, dynamic>.from(calls.single.arguments as Map);
    expect(args['timestamp'], 1760000000000);
    expect(args['source'], 'session');
    expect(args['action'], kSleepDetectedAction);
    expect(kSleepDetectedAction, 'com.sleepstop.sleep_stop.SLEEP_DETECTED');
  });

  test('is driven by the intent toggle only', () {
    const action = BroadcastIntentAction(channel: channel);
    expect(action.isEnabled(const SleepSettings()), isFalse);
    expect(
      action.isEnabled(
        const SleepSettings(
          sleepActions: SleepActionsSettings(
            enabled: true,
            intent: IntentActionSettings(enabled: true),
          ),
        ),
      ),
      isTrue,
    );
  });

  test('a native failure surfaces as an error (handled by the dispatcher)', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'HOME_ACTIONS_ERROR');
        });
    const action = BroadcastIntentAction(channel: channel);
    await expectLater(action.execute(ctx()), throwsA(isA<PlatformException>()));
  });
}
