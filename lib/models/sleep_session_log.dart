import 'dart:convert';
import 'sleep_settings.dart';

class SleepSessionLog {
  final String id;
  final DetectionMode mode;
  final DateTime startTime;
  final DateTime asleepTime;
  final DateTime pausedAtTime;
  final int listeningDurationSeconds;
  final String triggerReason;
  final int? finalBpm;
  final double? baselineBpm;
  final String? watchName;
  final String? mediaAppName;
  final String? mediaTitle;
  final List<String> closedApps;
  final List<int> bpmTimeline;

  const SleepSessionLog({
    required this.id,
    required this.mode,
    required this.startTime,
    required this.asleepTime,
    required this.pausedAtTime,
    required this.listeningDurationSeconds,
    required this.triggerReason,
    this.finalBpm,
    this.baselineBpm,
    this.watchName,
    this.mediaAppName,
    this.mediaTitle,
    this.closedApps = const [],
    this.bpmTimeline = const [],
  });

  int get listeningMinutesRounded {
    final minutes = (listeningDurationSeconds / 60).round();
    return minutes < 1 && listeningDurationSeconds > 0 ? 1 : minutes;
  }

  String get formattedListeningDuration {
    if (listeningDurationSeconds < 60) {
      return '$listeningDurationSeconds sec';
    }
    final hours = listeningDurationSeconds ~/ 3600;
    final minutes = (listeningDurationSeconds % 3600) ~/ 60;
    final seconds = listeningDurationSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (seconds > 0 && minutes < 10) {
      return '$minutes min ${seconds}s';
    }
    return '$minutes minutes';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mode': mode.name,
      'startTime': startTime.toIso8601String(),
      'asleepTime': asleepTime.toIso8601String(),
      'pausedAtTime': pausedAtTime.toIso8601String(),
      'listeningDurationSeconds': listeningDurationSeconds,
      'triggerReason': triggerReason,
      'finalBpm': finalBpm,
      'baselineBpm': baselineBpm,
      'watchName': watchName,
      'mediaAppName': mediaAppName,
      'mediaTitle': mediaTitle,
      'closedApps': closedApps,
      'bpmTimeline': bpmTimeline,
    };
  }

  factory SleepSessionLog.fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'] as String?;
    final mode = DetectionMode.values.firstWhere(
      (e) => e.name == modeName,
      orElse: () => DetectionMode.watchBle,
    );

    final startTime = DateTime.parse(json['startTime'] as String);
    final asleepTime = DateTime.parse(json['asleepTime'] as String);
    final pausedAtTime = json['pausedAtTime'] != null
        ? DateTime.parse(json['pausedAtTime'] as String)
        : asleepTime;

    final rawClosed = json['closedApps'] as List<dynamic>?;
    final rawTimeline = json['bpmTimeline'] as List<dynamic>?;

    return SleepSessionLog(
      id: json['id'] as String,
      mode: mode,
      startTime: startTime,
      asleepTime: asleepTime,
      pausedAtTime: pausedAtTime,
      listeningDurationSeconds:
          (json['listeningDurationSeconds'] as num?)?.toInt() ??
          asleepTime.difference(startTime).inSeconds.clamp(0, 86400),
      triggerReason: json['triggerReason'] as String? ?? 'Sleep detected',
      finalBpm: (json['finalBpm'] as num?)?.toInt(),
      baselineBpm: (json['baselineBpm'] as num?)?.toDouble(),
      watchName: json['watchName'] as String?,
      mediaAppName: json['mediaAppName'] as String?,
      mediaTitle: json['mediaTitle'] as String?,
      closedApps: rawClosed != null
          ? rawClosed.map((e) => e.toString()).toList()
          : const [],
      bpmTimeline: rawTimeline != null
          ? rawTimeline.map((e) => (e as num).toInt()).toList()
          : const [],
    );
  }

  static String encodeList(List<SleepSessionLog> logs) {
    return jsonEncode(logs.map((e) => e.toJson()).toList());
  }

  static List<SleepSessionLog> decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => SleepSessionLog.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
