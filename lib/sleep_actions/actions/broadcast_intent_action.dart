import 'package:flutter/services.dart';
import '../../app_info.dart';
import '../../models/sleep_settings.dart';
import '../sleep_action.dart';

/// Sends the public broadcast `com.sleepstop.sleep_stop.SLEEP_DETECTED`
/// (extras: `timestamp` epoch ms, `source`) for Tasker / Automate.
class BroadcastIntentAction implements SleepAction {
  static const String actionId = 'intent';
  static const MethodChannel defaultChannel = MethodChannel(
    'com.sleepstop/home_actions',
  );

  final MethodChannel _channel;

  const BroadcastIntentAction({MethodChannel channel = defaultChannel})
    : _channel = channel;

  @override
  String get id => actionId;

  @override
  bool isEnabled(SleepSettings settings) => settings.sleepActions.intent.enabled;

  @override
  Future<void> execute(SleepActionContext context) async {
    final ok = await _channel.invokeMethod<bool>('sendSleepBroadcast', {
      'timestamp': context.event.timestamp.millisecondsSinceEpoch,
      'source': context.event.source,
      'action': kSleepDetectedAction,
    });
    if (ok != true) {
      throw StateError('broadcast not sent');
    }
  }

  @override
  Future<void> cancel() async {
    // A broadcast is instantaneous: nothing to cancel.
  }
}
