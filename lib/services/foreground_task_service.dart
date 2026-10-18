import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startSleepStopForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(SleepStopTaskHandler());
}

class SleepStopTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain({
      'event': 'heartbeat',
      'timestamp': timestamp.toIso8601String(),
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop_session') {
      FlutterForegroundTask.sendDataToMain({'event': 'stop_session'});
    } else if (id == 'still_awake') {
      FlutterForegroundTask.sendDataToMain({'event': 'still_awake'});
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}

class ForegroundTaskService {
  static final ForegroundTaskService instance = ForegroundTaskService._();
  ForegroundTaskService._();

  bool _initialized = false;

  /// Localized label of the "stop" action button, set by the session provider.
  String stopButtonLabel = 'Stop';

  /// Localized label of the "still awake" button shown during the grace window.
  String stillAwakeButtonLabel = 'Still awake';

  List<NotificationButton> _buttons({bool withStillAwake = false}) => [
    if (withStillAwake)
      NotificationButton(id: 'still_awake', text: stillAwakeButtonLabel),
    NotificationButton(id: 'stop_session', text: stopButtonLabel),
  ];

  void init({String? channelName, String? channelDescription}) {
    if (_initialized) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sleepstop_active_monitoring',
        channelName: channelName ?? 'SleepStop',
        channelDescription: channelDescription ??
            'Keeps heart rate and motion sleep detection active while screen is off.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: true,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: true,
      ),
    );
    _initialized = true;
  }

  Future<void> startMonitoringService({
    required String title,
    required String text,
  }) async {
    init();
    try {
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
          notificationButtons: _buttons(),
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 2048,
          serviceTypes: const [
            ForegroundServiceTypes.connectedDevice,
            ForegroundServiceTypes.specialUse,
          ],
          notificationTitle: title,
          notificationText: text,
          notificationButtons: _buttons(),
          callback: startSleepStopForegroundCallback,
        );
      }
    } catch (_) {}
  }

  Future<void> updateNotification({
    required String title,
    required String text,
    bool withStillAwakeButton = false,
  }) async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
          notificationButtons: _buttons(withStillAwake: withStillAwakeButton),
        );
      }
    } catch (_) {}
  }

  Future<void> stopMonitoringService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}
