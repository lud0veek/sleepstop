import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_session_log.dart';
import '../models/sleep_settings.dart';

class StorageService {
  static const String _settingsKey = 'sleepstop_settings_v1';
  static const String _logsKey = 'sleepstop_session_logs_v1';

  Future<SleepSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return const SleepSettings(isHydrated: true);
    }
    return SleepSettings.decode(raw);
  }

  Future<void> saveSettings(SleepSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, settings.encode());
  }

  Future<List<SleepSessionLog>> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_logsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    return SleepSessionLog.decodeList(raw);
  }

  Future<void> saveLogs(List<SleepSessionLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logsKey, SleepSessionLog.encodeList(logs));
  }
}
