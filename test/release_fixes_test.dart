import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_stop/l10n/app_strings.dart';
import 'package:sleep_stop/models/sleep_settings.dart';
import 'package:sleep_stop/providers/session_logs_provider.dart';
import 'package:sleep_stop/providers/settings_provider.dart';
import 'package:sleep_stop/models/sleep_session_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Free trial counter', () {
    test('is persisted in settings JSON and survives a round-trip', () {
      const settings = SleepSettings(trialNightsUsed: 3);
      final decoded = SleepSettings.decode(settings.encode());
      expect(decoded.trialNightsUsed, 3);
      expect(decoded.remainingTrialNights, 2);
    });

    test('defaults to 0 for settings saved by older app versions', () {
      final decoded = SleepSettings.decode('{"languageCode":"nl"}');
      expect(decoded.trialNightsUsed, 0);
      expect(decoded.remainingTrialNights, SleepSettings.totalFreeTrialNights);
      expect(decoded.onboardingPermissionsShown, isFalse);
    });

    test('never goes below zero remaining nights', () {
      const settings = SleepSettings(trialNightsUsed: 42);
      expect(settings.remainingTrialNights, 0);
    });

    test('survives clearing the session history', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider.notifier);
      final logs = container.read(sessionLogsProvider.notifier);
      // Let the async initial load complete before mutating.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final log = SleepSessionLog(
        id: '1',
        mode: DetectionMode.phoneFadeShake,
        startTime: DateTime(2026, 1, 1, 22),
        asleepTime: DateTime(2026, 1, 1, 22, 20),
        pausedAtTime: DateTime(2026, 1, 1, 22, 21),
        listeningDurationSeconds: 1200,
        triggerReason: 'test',
      );
      await logs.addSessionLog(log);
      await settings.consumeTrialNight();
      await settings.consumeTrialNight();
      expect(container.read(settingsProvider).trialNightsUsed, 2);

      await logs.clearAllLogs();
      expect(container.read(sessionLogsProvider), isEmpty);
      expect(container.read(settingsProvider).trialNightsUsed, 2);

      // A reset of tuning settings must not refund trial nights either.
      await settings.resetAllSettingsAndLearnedData();
      expect(container.read(settingsProvider).trialNightsUsed, 2);
    });

    test('is not consumed once Pro is unlocked', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final settings = container.read(settingsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await settings.setProUnlocked(true);
      await settings.consumeTrialNight();
      expect(container.read(settingsProvider).trialNightsUsed, 0);
    });
  });

  group('Notification & tile strings are localized', () {
    test('stop button and tile labels differ per language and are non-empty',
        () {
      final values = <String>{};
      for (final lang in AppStrings.supportedLanguages) {
        final s = AppStrings(lang);
        expect(s.stopSessionButton, isNotEmpty);
        expect(s.tileReady, isNotEmpty);
        expect(s.tileActive, isNotEmpty);
        expect(s.fgTitleWatch, contains('SleepStop'));
        expect(s.fgBpmTitle('62 BPM', 55), contains('62 BPM'));
        expect(s.summaryTitle('23:12', '18 min'), contains('23:12'));
        expect(s.triggerReasonHr(54, baselineBpm: 66, stdDevBpm: 1.2),
            contains('54'));
        values.add(s.stopSessionButton);
      }
      expect(values.length, AppStrings.supportedLanguages.length);
    });

    test('no English leftovers in the French notification strings', () {
      final s = AppStrings('fr');
      for (final text in [
        s.stopSessionButton,
        s.fgMonitoring,
        s.fgTitlePhone,
        s.fgNextCheck(15),
        s.triggerReasonFade,
      ]) {
        expect(text.toLowerCase(), isNot(contains('session stopped')));
        expect(text.toLowerCase(), isNot(contains('monitoring')));
        expect(text.toLowerCase(), isNot(contains('stop session')));
      }
    });
  });
}
