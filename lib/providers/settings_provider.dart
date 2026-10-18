import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../models/sleep_settings.dart';
import '../services/storage_service.dart';
import '../services/telemetry_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final settingsProvider = NotifierProvider<SettingsNotifier, SleepSettings>(
  SettingsNotifier.new,
);

final appStringsProvider = Provider<AppStrings>((ref) {
  final lang = ref.watch(settingsProvider.select((s) => s.languageCode));
  return AppStrings(lang);
});

class SettingsNotifier extends Notifier<SleepSettings> {
  late final StorageService _storage;

  @override
  SleepSettings build() {
    _storage = ref.read(storageServiceProvider);
    _loadInitial();
    return const SleepSettings();
  }

  Future<void> _loadInitial() async {
    final loaded = await _storage.loadSettings();
    state = loaded;
    unawaited(
      TelemetryService.instance.recordAppOpen(
        enabled: loaded.anonymousTelemetryEnabled,
        languageCode: loaded.languageCode,
      ),
    );
  }

  Future<void> _update(SleepSettings updated) async {
    state = updated;
    await _storage.saveSettings(updated);
  }

  Future<void> setPreferredMode(DetectionMode mode) =>
      _update(state.copyWith(preferredMode: mode));

  Future<void> setBiometricTriggerMode(BiometricTriggerMode mode) =>
      _update(state.copyWith(biometricTriggerMode: mode));

  Future<void> setAdaptiveSensitivity(AdaptiveSensitivity sensitivity) {
    final recommendedMinutes = switch (sensitivity) {
      AdaptiveSensitivity.fast => 3,
      AdaptiveSensitivity.balanced => 4,
      AdaptiveSensitivity.deep => 6,
    };
    return _update(
      state.copyWith(
        adaptiveSensitivity: sensitivity,
        confirmationDurationMinutes: recommendedMinutes,
      ),
    );
  }

  Future<void> setSleepBpmThreshold(int bpm) =>
      _update(state.copyWith(sleepBpmThreshold: bpm.clamp(40, 100)));

  Future<void> setUseAutoBaseline(bool enabled) =>
      _update(state.copyWith(useAutoBaseline: enabled));

  Future<void> setAutoBaselineDropPercent(double percent) =>
      _update(state.copyWith(autoBaselineDropPercent: percent.clamp(5.0, 25.0)));

  Future<void> setConfirmationDurationMinutes(int minutes) =>
      _update(state.copyWith(confirmationDurationMinutes: minutes.clamp(1, 20)));

  Future<void> setCheckIntervalMinutes(int minutes) =>
      _update(state.copyWith(checkIntervalMinutes: minutes.clamp(1, 90)));

  Future<void> setShakeSensitivity(double sensitivity) =>
      _update(state.copyWith(shakeSensitivity: sensitivity.clamp(0.5, 6.0)));

  Future<void> setRewindOnPause(bool rewind) =>
      _update(state.copyWith(rewindOnPause: rewind));

  Future<void> setCloseAppsOnSleep(bool closeApps) =>
      _update(state.copyWith(closeAppsOnSleep: closeApps));

  Future<void> setReturnToHomeOnSleep(bool goHome) =>
      _update(state.copyWith(returnToHomeOnSleep: goHome));

  Future<void> toggleTargetApp(String packageName, String appName) {
    final nextMap = Map<String, String>.from(state.targetAppsToClose);
    if (nextMap.containsKey(packageName)) {
      nextMap.remove(packageName);
    } else {
      nextMap[packageName] = appName;
    }
    return _update(state.copyWith(targetAppsToClose: nextMap));
  }

  Future<void> setSavedWatch({String? id, String? name}) => _update(
    state.copyWith(
      savedWatchId: id,
      savedWatchName: name,
      clearSavedWatch: id == null,
    ),
  );

  Future<void> recordLearnedSleepingBpm(int asleepBpm) {
    final currentLearned = state.learnedSleepingBpm;
    final updatedLearned = currentLearned == null
        ? asleepBpm.toDouble()
        : (currentLearned * 0.7) + (asleepBpm * 0.3);
    return _update(state.copyWith(learnedSleepingBpm: updatedLearned));
  }

  Future<void> setLanguageCode(String code) async {
    await _update(state.copyWith(languageCode: code));
    await TelemetryService.instance.recordLanguageSwitch(
      enabled: state.anonymousTelemetryEnabled,
      newLanguageCode: code,
    );
  }

  Future<void> setProUnlocked(bool unlocked) =>
      _update(state.copyWith(isProUnlocked: unlocked));

  Future<void> setAnonymousTelemetryEnabled(bool enabled) =>
      _update(state.copyWith(anonymousTelemetryEnabled: enabled));

  Future<void> resetAllSettingsAndLearnedData() async {
    const fresh = SleepSettings();
    state = fresh;
    await _storage.saveSettings(fresh);
  }
}
