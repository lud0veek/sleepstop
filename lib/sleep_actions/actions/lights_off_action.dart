import 'package:flutter/services.dart';
import '../../models/sleep_settings.dart';
import '../sleep_action.dart';

/// Availability of the Google Home integration on this device/build.
enum LightsAvailability {
  available,
  unsupportedAndroid,
  playServicesMissing,
  playServicesOutdated,
  sdkMissing,
  sdkError,
}

/// Google Home permission state for this app.
enum LightsPermission { granted, notGranted, unavailable, uninitialized, error }

class LightDevice {
  final String id;
  final String name;
  final bool hasLevel;
  final bool online;
  const LightDevice({
    required this.id,
    required this.name,
    required this.hasLevel,
    required this.online,
  });
}

class LightRoom {
  final String id;
  final String name;
  final List<LightDevice> devices;
  const LightRoom({required this.id, required this.name, required this.devices});
}

class LightStructure {
  final String id;
  final String name;
  final List<LightRoom> rooms;
  final List<LightDevice> unassigned;
  const LightStructure({
    required this.id,
    required this.name,
    required this.rooms,
    required this.unassigned,
  });
}

/// Labels the native side needs for its "cancel the fade" notification.
class LightsNotificationLabels {
  final String title;
  final String body;
  final String cancelButton;
  final String channelName;
  const LightsNotificationLabels({
    required this.title,
    required this.body,
    required this.cancelButton,
    required this.channelName,
  });

  Map<String, String> toMap() => {
    'title': title,
    'body': body,
    'cancelButton': cancelButton,
    'channelName': channelName,
  };
}

/// Thin Dart wrapper over the native Google Home bridge. No business logic
/// here: everything (snapshot, fade, restore) runs in Kotlin.
class LightsBridge {
  static const MethodChannel defaultChannel = MethodChannel(
    'com.sleepstop/home_actions',
  );
  final MethodChannel _channel;
  const LightsBridge({MethodChannel channel = defaultChannel})
    : _channel = channel;

  Future<(LightsAvailability, String?)> checkAvailability() async {
    final m = await _channel.invokeMapMethod<String, dynamic>(
      'checkAvailability',
    );
    return (_availability(m?['status'] as String?), m?['detail'] as String?);
  }

  Future<(LightsPermission, String?)> permissionState() async {
    final m = await _channel.invokeMapMethod<String, dynamic>(
      'permissionState',
    );
    return (_permission(m?['state'] as String?), m?['structureName'] as String?);
  }

  /// `granted`, `cancelled` or `error`.
  Future<(String, String?)> requestPermissions() async {
    final m = await _channel.invokeMapMethod<String, dynamic>(
      'requestPermissions',
    );
    return ((m?['result'] as String?) ?? 'error', m?['detail'] as String?);
  }

  Future<List<LightStructure>> listLights() async {
    final raw = await _channel.invokeListMethod<dynamic>('listLights');
    return (raw ?? const [])
        .whereType<Map>()
        .map((s) => LightStructure(
              id: s['id'].toString(),
              name: (s['name'] ?? '').toString(),
              rooms: (s['rooms'] as List? ?? const [])
                  .whereType<Map>()
                  .map((r) => LightRoom(
                        id: r['id'].toString(),
                        name: (r['name'] ?? '').toString(),
                        devices: _devices(r['devices']),
                      ))
                  .toList(),
              unassigned: _devices(s['unassigned']),
            ))
        .toList();
  }

  Future<void> executeLightsOff({
    required List<String> deviceIds,
    required List<String> roomIds,
    required int fadeSeconds,
    required LightsNotificationLabels labels,
  }) async {
    final m = await _channel.invokeMapMethod<String, dynamic>(
      'executeLightsOff',
      {
        'deviceIds': deviceIds,
        'roomIds': roomIds,
        'fadeSeconds': fadeSeconds,
        'labels': labels.toMap(),
      },
    );
    if (m?['started'] != true) {
      throw StateError((m?['error'] as String?) ?? 'notStarted');
    }
  }

  Future<bool> cancelAndRestore() async {
    final m = await _channel.invokeMapMethod<String, dynamic>(
      'cancelAndRestore',
    );
    return m?['restored'] == true;
  }

  static List<LightDevice> _devices(Object? raw) => (raw as List? ?? const [])
      .whereType<Map>()
      .map((d) => LightDevice(
            id: d['id'].toString(),
            name: (d['name'] ?? '').toString(),
            hasLevel: d['hasLevel'] == true,
            online: d['online'] != false,
          ))
      .toList();

  static LightsAvailability _availability(String? s) => switch (s) {
    'available' => LightsAvailability.available,
    'unsupportedAndroid' => LightsAvailability.unsupportedAndroid,
    'playServicesMissing' => LightsAvailability.playServicesMissing,
    'playServicesOutdated' => LightsAvailability.playServicesOutdated,
    'sdkMissing' => LightsAvailability.sdkMissing,
    _ => LightsAvailability.sdkError,
  };

  static LightsPermission _permission(String? s) => switch (s) {
    'granted' => LightsPermission.granted,
    'notGranted' => LightsPermission.notGranted,
    'unavailable' => LightsPermission.unavailable,
    'uninitialized' => LightsPermission.uninitialized,
    _ => LightsPermission.error,
  };
}

/// Turns the selected Google Home lights off (with a fade) when sleep is
/// confirmed. `execute` returns as soon as the native fade is running: the
/// fade itself (up to 2 min) and its "cancel" notification are native, so
/// the dispatcher's 10 s timeout only covers the start.
class LightsOffAction implements SleepAction {
  static const String actionId = 'lights';

  final LightsBridge bridge;
  final LightsNotificationLabels Function() labels;

  const LightsOffAction({required this.bridge, required this.labels});

  @override
  String get id => actionId;

  @override
  bool isEnabled(SleepSettings settings) {
    final l = settings.sleepActions.lights;
    return l.enabled && (l.deviceIds.isNotEmpty || l.roomIds.isNotEmpty);
  }

  @override
  Future<void> execute(SleepActionContext context) async {
    final l = context.settings.sleepActions.lights;
    await bridge.executeLightsOff(
      deviceIds: l.deviceIds,
      roomIds: l.roomIds,
      fadeSeconds: l.fade.seconds,
      labels: labels(),
    );
  }

  @override
  Future<void> cancel() async {
    try {
      await bridge.cancelAndRestore();
    } catch (_) {}
  }
}
