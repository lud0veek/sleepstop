import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class PermissionService {
  static final PermissionService instance = PermissionService._();
  PermissionService._();

  static const MethodChannel _channel = MethodChannel(
    'com.sleepstop/media_control',
  );

  Future<void> requestAllRequiredPermissions() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod<bool>('requestRuntimePermissions');
    } catch (_) {}

    try {
      final notifPerm =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notifPerm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {}

    try {
      final ignoringBatteryOpt =
          await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!ignoringBatteryOpt) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (_) {}
  }
}
