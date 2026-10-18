import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sleep_settings.dart';
import '../providers/session_logs_provider.dart';
import '../providers/settings_provider.dart';
import '../services/billing_service.dart';
import 'theme/oled_theme.dart';

class ProUnlockSheet extends ConsumerWidget {
  const ProUnlockSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OledColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const ProUnlockSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final logs = ref.watch(sessionLogsProvider);
    final billing = ref.watch(billingProvider);
    final s = ref.watch(appStringsProvider);
    final lang = settings.languageCode;

    final usedNights = logs.length;
    final remainingNights =
        (SleepSettings.totalFreeTrialNights - usedNights).clamp(
          0,
          SleepSettings.totalFreeTrialNights,
        );

    String tr({
      required String fr,
      required String nl,
      required String de,
      required String es,
    }) => switch (lang) {
      'nl' => nl,
      'de' => de,
      'es' => es,
      _ => fr,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: OledColors.subtleBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        OledColors.warmAmber.withValues(alpha: 0.25),
                        OledColors.softIndigo.withValues(alpha: 0.22),
                      ],
                    ),
                    border: Border.all(
                      color: OledColors.warmAmber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: OledColors.warmAmber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.unlockProTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: OledColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.unlockProSubtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: OledColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OledColors.elevatedSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: settings.isProUnlocked
                      ? OledColors.calmTeal.withValues(alpha: 0.45)
                      : OledColors.warmAmber.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    settings.isProUnlocked
                        ? Icons.verified_rounded
                        : Icons.nights_stay_rounded,
                    color: settings.isProUnlocked
                        ? OledColors.calmTeal
                        : OledColors.warmAmber,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      settings.isProUnlocked
                          ? s.proActiveBadge
                          : s.trialBadgeText(remainingNights),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: settings.isProUnlocked
                            ? OledColors.calmTeal
                            : OledColors.warmAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildFeatureRow(
              Icons.favorite_rounded,
              tr(
                fr: 'Nuits illimitées avec détection biométrique adaptative (Garmin, Whoop, Polar...)',
                nl: 'Onbeperkte nachten met adaptieve biometrische detectie (Garmin, Whoop, Polar...)',
                de: 'Unbegrenzte Nächte mit adaptiver biometrischer Erkennung (Garmin, Whoop, Polar...)',
                es: 'Noches ilimitadas con detección biométrica adaptativa (Garmin, Whoop, Polar...)',
              ),
            ),
            const SizedBox(height: 10),
            _buildFeatureRow(
              Icons.power_settings_new_rounded,
              tr(
                fr: 'Fermeture forcée illimitée des apps (YouTube, Netflix, Audible, Spotify, Twitch)',
                nl: 'Onbeperkt geforceerd sluiten van apps (YouTube, Netflix, Audible, Spotify, Twitch)',
                de: 'Unbegrenztes Schließen von Apps (YouTube, Netflix, Audible, Spotify, Twitch)',
                es: 'Cierre forzado ilimitado de apps (YouTube, Netflix, Audible, Spotify, Twitch)',
              ),
            ),
            const SizedBox(height: 10),
            _buildFeatureRow(
              Icons.dashboard_customize_rounded,
              tr(
                fr: 'Tuile de lancement rapide Android + Courbe BPM complète de tes nuits',
                nl: 'Android Snelkoppelingstegel + Volledige BPM-curve van je nachten',
                de: 'Android-Schnellstartkachel + Vollständige BPM-Kurve deiner Nächte',
                es: 'Acceso rápido de Android + Curva BPM completa de tus noches',
              ),
            ),
            const SizedBox(height: 20),

            if (!settings.isProUnlocked) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: billing.isLoading
                      ? null
                      : () async {
                          final status = await ref
                              .read(billingProvider.notifier)
                              .buyLifetimePro();
                          if (!context.mounted) return;
                          if (status ==
                              BillingResultStatus.unlockedDebugFallback) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(s.proActiveBadge),
                                backgroundColor: OledColors.elevatedSurface,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  icon: billing.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: OledColors.trueBlack,
                          ),
                        )
                      : const Icon(Icons.lock_open_rounded, size: 18),
                  label: Text(
                    s.unlockProCta,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: OledColors.warmAmber,
                    foregroundColor: OledColors.trueBlack,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: billing.isLoading
                      ? null
                      : () async {
                          await ref
                              .read(billingProvider.notifier)
                              .restorePurchases();
                          if (!context.mounted) return;
                          if (ref.read(settingsProvider).isProUnlocked) {
                            Navigator.of(context).pop();
                          }
                        },
                  child: Text(
                    s.restorePurchaseBtn,
                    style: const TextStyle(
                      fontSize: 12,
                      color: OledColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.check_circle_rounded,
                    color: OledColors.calmTeal,
                  ),
                  label: Text(
                    s.proActiveBadge,
                    style: const TextStyle(
                      color: OledColors.calmTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: OledColors.calmTeal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: OledColors.calmTeal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: OledColors.textPrimary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
