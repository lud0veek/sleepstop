import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sleep_session_log.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';

final sessionLogsProvider =
    NotifierProvider<SessionLogsNotifier, List<SleepSessionLog>>(
      SessionLogsNotifier.new,
    );

class SessionLogsNotifier extends Notifier<List<SleepSessionLog>> {
  late final StorageService _storage;

  @override
  List<SleepSessionLog> build() {
    _storage = ref.read(storageServiceProvider);
    _loadInitial();
    return const [];
  }

  Future<void> _loadInitial() async {
    final loaded = await _storage.loadLogs();
    state = loaded;
  }

  Future<void> addSessionLog(SleepSessionLog log) async {
    final updated = [log, ...state];
    state = updated;
    await _storage.saveLogs(updated);
  }

  Future<void> deleteSessionLog(String id) async {
    final updated = state.where((e) => e.id != id).toList();
    state = updated;
    await _storage.saveLogs(updated);
  }

  Future<void> clearAllLogs() async {
    state = const [];
    await _storage.saveLogs(const []);
  }
}
