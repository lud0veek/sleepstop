import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_stop/models/sleep_settings.dart';
import 'package:sleep_stop/sleep_actions/actions/lights_off_action.dart';
import 'package:sleep_stop/sleep_actions/sleep_action.dart';
import 'package:sleep_stop/sleep_actions/sleep_event_bus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.sleepstop/home_actions');
  final calls = <MethodCall>[];
  Map<String, dynamic> Function(MethodCall call)? responder;

  setUp(() {
    calls.clear();
    responder = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return responder?.call(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const labels = LightsNotificationLabels(
    title: 't',
    body: 'b',
    cancelButton: 'c',
    channelName: 'ch',
  );
  const bridge = LightsBridge(channel: channel);
  final action = LightsOffAction(bridge: bridge, labels: () => labels);

  SleepActionContext ctx(LightsActionSettings lights) => SleepActionContext(
    event: SleepDetectedEvent(
      timestamp: DateTime(2026, 10, 19, 23),
      mode: DetectionMode.watchBle,
    ),
    settings: SleepSettings(
      sleepActions: SleepActionsSettings(enabled: true, lights: lights),
    ),
  );

  test('enabled only with the toggle AND a selection', () {
    expect(action.isEnabled(const SleepSettings()), isFalse);
    expect(
      action.isEnabled(ctx(const LightsActionSettings(enabled: true)).settings),
      isFalse,
    );
    expect(
      action.isEnabled(
        ctx(const LightsActionSettings(enabled: true, roomIds: ['r1'])).settings,
      ),
      isTrue,
    );
  });

  test('execute forwards selection, fade seconds and labels; succeeds when started',
      () async {
    responder = (c) => {'started': true};
    await action.execute(ctx(const LightsActionSettings(
      enabled: true,
      deviceIds: ['d1', 'd2'],
      roomIds: ['r1'],
      fade: LightsFadeDuration.m2,
    )));
    expect(calls.single.method, 'executeLightsOff');
    final args = Map<String, dynamic>.from(calls.single.arguments as Map);
    expect(args['deviceIds'], ['d1', 'd2']);
    expect(args['roomIds'], ['r1']);
    expect(args['fadeSeconds'], 120);
    expect(Map<String, dynamic>.from(args['labels'] as Map)['cancelButton'], 'c');
  });

  test('execute fails when the native side could not start the fade', () async {
    responder = (c) => {'started': false, 'error': 'noDevice'};
    await expectLater(
      action.execute(ctx(const LightsActionSettings(enabled: true, deviceIds: ['x']))),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'noDevice')),
    );
  });

  test('cancel calls cancelAndRestore and never throws', () async {
    responder = (c) => throw PlatformException(code: 'X');
    await expectLater(action.cancel(), completes);
    expect(calls.single.method, 'cancelAndRestore');
  });

  test('listLights parses structures, rooms, devices and unassigned', () async {
    responder = (c) => {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return [
            {
              'id': 's1',
              'name': 'Maison',
              'rooms': [
                {
                  'id': 'r1',
                  'name': 'Chambre',
                  'devices': [
                    {'id': 'd1', 'name': 'Lampe', 'hasLevel': true, 'online': true},
                  ],
                },
              ],
              'unassigned': [
                {'id': 'd9', 'name': 'Hall', 'hasLevel': false, 'online': false},
              ],
            },
          ];
        });
    final list = await bridge.listLights();
    expect(list.single.name, 'Maison');
    expect(list.single.rooms.single.devices.single.hasLevel, isTrue);
    expect(list.single.unassigned.single.online, isFalse);
  });

  test('availability and permission parsing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'checkAvailability' => {'status': 'sdkMissing', 'detail': 'x'},
            'permissionState' => {'state': 'granted', 'structureName': 'Maison'},
            _ => null,
          };
        });
    expect((await bridge.checkAvailability()).$1, LightsAvailability.sdkMissing);
    final p = await bridge.permissionState();
    expect(p.$1, LightsPermission.granted);
    expect(p.$2, 'Maison');
  });
}
