import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../l10n/app_strings.dart';
import '../models/sleep_session_log.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _summaryChannelId = 'sleepstop_morning_summary';

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

  Future<void> showSleepSummaryNotification(
    SleepSessionLog log,
    AppStrings s,
  ) async {
    await init();

    final timeFormat = DateFormat('HH:mm');
    final startStr = timeFormat.format(log.startTime);
    final asleepStr = timeFormat.format(log.asleepTime);
    final durationStr = log.formattedListeningDuration;

    final title = s.summaryTitle(asleepStr, durationStr);
    final body = s.summaryBody(
      startStr,
      asleepStr,
      durationStr,
      log.triggerReason,
    );

    final androidDetails = AndroidNotificationDetails(
      _summaryChannelId,
      s.summaryChannelName,
      channelDescription: s.summaryChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: s.summaryFooter,
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
