import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../models/sleep_session_log.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _summaryChannelId = 'sleepstop_morning_summary';
  static const String _summaryChannelName = 'Morning Sleep Summary';
  static const String _summaryChannelDesc =
      'Notifications showing when media was paused and how far to rewind.';

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (_) {
      // Safe fallback in test environments
    }
  }

  Future<void> showSleepSummaryNotification(SleepSessionLog log) async {
    await init();

    final timeFormat = DateFormat('HH:mm');
    final startStr = timeFormat.format(log.startTime);
    final asleepStr = timeFormat.format(log.asleepTime);
    final durationStr = log.formattedListeningDuration;

    final title =
        'Media Paused at $asleepStr • Rewind / Seek +$durationStr';
    final body =
        'Session: $startStr → $asleepStr ($durationStr listened). '
        'Reason: ${log.triggerReason}.';

    final androidDetails = AndroidNotificationDetails(
      _summaryChannelId,
      _summaryChannelName,
      channelDescription: _summaryChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'SleepStop Morning Rewind Helper',
      ),
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        id: 1001,
        title: title,
        body: body,
        notificationDetails: details,
        payload: log.id,
      );
    } catch (_) {}
  }
}
