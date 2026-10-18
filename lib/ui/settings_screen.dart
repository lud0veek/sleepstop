import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_info.dart';
import '../l10n/app_strings.dart';
import '../models/sleep_settings.dart';
import '../providers/session_logs_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sleep_session_provider.dart';
import 'privacy_sheet.dart';
import 'pro_unlock_sheet.dart';
import 'target_apps_sheet.dart';
import 'theme/oled_theme.dart';
import 'watch_guide_sheet.dart';
import 'widgets/flag_icon.dart';

/// The single home of every setting. Five sections, one entry point
/// (the gear icon in the app bar).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final s = ref.watch(appStringsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final session = ref.watch(sleepSessionProvider);
    final isSmart =
        settings.biometricTriggerMode == BiometricTriggerMode.smartAdaptive;

    return Scaffold(
      backgroundColor: OledColors.trueBlack,
      appBar: AppBar(
        backgroundColor: OledColors.trueBlack,
        surfaceTintColor: Colors.transparent,
        title: Text(
          s.settingsSheetTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: OledColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // ------------------------------------------------------------------
          // 1. Detection
          // ------------------------------------------------------------------
          _Section(
            icon: Icons.monitor_heart_outlined,
            accent: OledColors.warmAmber,
            title: s.tr(
              fr: 'Détection du sommeil',
              nl: 'Slaapdetectie',
              de: 'Schlaferkennung',
              es: 'Detección del sueño',
            ),
            children: [
              _Label(
                s.tr(
                  fr: 'Mode par défaut',
                  nl: 'Standaardmodus',
                  de: 'Standardmodus',
                  es: 'Modo por defecto',
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<DetectionMode>(
                segments: [
                  ButtonSegment(
                    value: DetectionMode.watchBle,
                    icon: const Icon(Icons.watch_rounded, size: 16),
                    label: Text(s.modeWatchBle, maxLines: 1),
                  ),
                  ButtonSegment(
                    value: DetectionMode.phoneFadeShake,
                    icon: const Icon(Icons.vibration_rounded, size: 16),
                    label: Text(s.modePhoneShake, maxLines: 1),
                  ),
                ],
                selected: {settings.preferredMode},
                showSelectedIcon: false,
                onSelectionChanged: session.isRunning
                    ? null
                    : (sel) {
                        if (sel.isNotEmpty) {
                          ref
                              .read(sleepSessionProvider.notifier)
                              .selectMode(sel.first);
                        }
                      },
              ),
              if (session.isRunning)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    s.tr(
                      fr: 'Le mode se change quand aucune veille n\'est en cours.',
                      nl: 'De modus kan gewijzigd worden als er geen bewaking loopt.',
                      de: 'Der Modus lässt sich ändern, wenn keine Überwachung läuft.',
                      es: 'El modo se cambia cuando no hay vigilancia en curso.',
                    ),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: OledColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 18),

              // Watch settings
              _SubHeader(s.settingsWatchSection, color: OledColors.warmAmber),
              const SizedBox(height: 10),
              SegmentedButton<BiometricTriggerMode>(
                segments: [
                  ButtonSegment(
                    value: BiometricTriggerMode.smartAdaptive,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(
                      s.smartAdaptiveLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ButtonSegment(
                    value: BiometricTriggerMode.manualBpm,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(
                      s.manualBpmLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                selected: {settings.biometricTriggerMode},
                showSelectedIcon: false,
                onSelectionChanged: (sel) {
                  if (sel.isNotEmpty) {
                    notifier.setBiometricTriggerMode(sel.first);
                  }
                },
              ),
              const SizedBox(height: 12),
              if (isSmart) ...[
                _InfoBox(
                  title: s.howSmartWorksTitle,
                  body: s.howSmartWorksBody,
                  footer: settings.learnedSleepingBpm != null
                      ? s.learnedSleepHrText(
                          settings.learnedSleepingBpm!.toStringAsFixed(0),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                _Label(s.sensitivityProfileTitle),
                const SizedBox(height: 8),
                ...AdaptiveSensitivity.values.map(
                  (preset) => _RadioRow(
                    selected: settings.adaptiveSensitivity == preset,
                    title: s.sensitivityTitle(preset),
                    subtitle: s.sensitivityDesc(preset),
                    onTap: () => notifier.setAdaptiveSensitivity(preset),
                  ),
                ),
              ] else ...[
                _SliderRow(
                  label: s.fixedBpmSliderLabel,
                  valueText: '${settings.sleepBpmThreshold} BPM',
                  value: settings.sleepBpmThreshold.toDouble(),
                  min: 40,
                  max: 85,
                  divisions: 45,
                  onChanged: (v) => notifier.setSleepBpmThreshold(v.round()),
                ),
                const SizedBox(height: 6),
                _SliderRow(
                  label: s.confirmationSliderLabel,
                  valueText: '${settings.confirmationDurationMinutes} min',
                  value: settings.confirmationDurationMinutes.toDouble(),
                  min: 1,
                  max: 15,
                  divisions: 14,
                  onChanged: (v) =>
                      notifier.setConfirmationDurationMinutes(v.round()),
                ),
              ],
              const SizedBox(height: 6),
              _LinkRow(
                icon: Icons.help_outline_rounded,
                color: OledColors.calmTeal,
                label: s.watchGuideTooltip,
                onTap: () => WatchGuideSheet.show(context),
              ),
              const SizedBox(height: 18),

              // Phone settings
              _SubHeader(s.settingsPhoneSection, color: OledColors.softIndigo),
              const SizedBox(height: 10),
              _SliderRow(
                label: s.timerIntervalSliderLabel,
                valueText: '${settings.checkIntervalMinutes} min',
                value: settings.checkIntervalMinutes.toDouble(),
                min: 1,
                max: 60,
                divisions: 59,
                onChanged: (v) => notifier.setCheckIntervalMinutes(v.round()),
              ),
              const SizedBox(height: 6),
              _SliderRow(
                label: s.shakeSensitivitySliderLabel,
                valueText:
                    '${settings.shakeSensitivity.toStringAsFixed(1)} m/s²',
                value: settings.shakeSensitivity,
                min: 0.5,
                max: 5.0,
                divisions: 45,
                onChanged: notifier.setShakeSensitivity,
              ),
            ],
          ),

          // ------------------------------------------------------------------
          // 2. When you fall asleep
          // ------------------------------------------------------------------
          _Section(
            icon: Icons.bedtime_rounded,
            accent: OledColors.softIndigo,
            title: s.tr(
              fr: 'À l\'endormissement',
              nl: 'Bij het inslapen',
              de: 'Beim Einschlafen',
              es: 'Al dormirse',
            ),
            children: [
              _Toggle(
                title: s.autoRewindTitle,
                subtitle: s.autoRewindSubtitle,
                value: settings.rewindOnPause,
                onChanged: notifier.setRewindOnPause,
              ),
              _Toggle(
                title: s.tr(
                  fr: 'Quitter le plein écran vidéo',
                  nl: 'Volledig scherm verlaten',
                  de: 'Video-Vollbild beenden',
                  es: 'Salir de pantalla completa',
                ),
                subtitle: s.tr(
                  fr: 'Revient à l\'accueil pour que YouTube, Netflix ou Twitch laisse l\'écran s\'éteindre.',
                  nl: 'Keert terug naar het startscherm zodat YouTube, Netflix of Twitch het scherm laat uitgaan.',
                  de: 'Kehrt zum Startbildschirm zurück, damit YouTube, Netflix oder Twitch das Display ausschalten lässt.',
                  es: 'Vuelve al inicio para que YouTube, Netflix o Twitch deje apagar la pantalla.',
                ),
                value: settings.returnToHomeOnSleep,
                onChanged: notifier.setReturnToHomeOnSleep,
              ),
              _Toggle(
                title: s.tr(
                  fr: 'Fermer les apps choisies',
                  nl: 'Gekozen apps sluiten',
                  de: 'Gewählte Apps schließen',
                  es: 'Cerrar las apps elegidas',
                ),
                subtitle: s.tr(
                  fr: 'Met en pause et quitte les lecteurs sélectionnés ci-dessous.',
                  nl: 'Pauzeert en sluit de hieronder gekozen spelers.',
                  de: 'Pausiert und beendet die unten gewählten Player.',
                  es: 'Pausa y cierra los reproductores seleccionados abajo.',
                ),
                value: settings.closeAppsOnSleep,
                onChanged: notifier.setCloseAppsOnSleep,
              ),
              const SizedBox(height: 4),
              _LinkRow(
                icon: Icons.apps_rounded,
                color: OledColors.softIndigo,
                label: s.appsToCloseTitle,
                trailing: settings.targetAppsToClose.isEmpty
                    ? s.noAppSelected
                    : '${settings.targetAppsToClose.length}',
                onTap: () => TargetAppsSheet.show(context),
              ),
            ],
          ),

          // ------------------------------------------------------------------
          // 3. Language
          // ------------------------------------------------------------------
          _Section(
            icon: Icons.language_rounded,
            accent: OledColors.calmTeal,
            title: s.tr(
              fr: 'Langue',
              nl: 'Taal',
              de: 'Sprache',
              es: 'Idioma',
            ),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppStrings.supportedLanguages.map((code) {
                  final selected = settings.languageCode == code;
                  return ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    avatar: FlagIcon(code: code, width: 18, radius: 2),
                    label: Text(AppStrings.languageName(code)),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? OledColors.trueBlack
                          : OledColors.textPrimary,
                    ),
                    selectedColor: OledColors.warmAmber,
                    backgroundColor: OledColors.elevatedSurface,
                    side: BorderSide(
                      color: selected
                          ? OledColors.warmAmber
                          : OledColors.subtleBorder,
                    ),
                    onSelected: (_) => notifier.setLanguageCode(code),
                  );
                }).toList(),
              ),
            ],
          ),

          // ------------------------------------------------------------------
          // 4. Privacy
          // ------------------------------------------------------------------
          _Section(
            icon: Icons.verified_user_outlined,
            accent: OledColors.calmTeal,
            title: s.tr(
              fr: 'Confidentialité',
              nl: 'Privacy',
              de: 'Datenschutz',
              es: 'Privacidad',
            ),
            children: [
              _Toggle(
                title: s.tr(
                  fr: 'Compteurs anonymes',
                  nl: 'Anonieme tellers',
                  de: 'Anonyme Zähler',
                  es: 'Contadores anónimos',
                ),
                subtitle: s.tr(
                  fr: 'Nombre d\'installations et de nuits détectées, sans aucune donnée personnelle ni pouls. Serveur en Belgique.',
                  nl: 'Aantal installaties en gedetecteerde nachten, zonder persoonsgegevens of hartslag. Server in België.',
                  de: 'Anzahl Installationen und erkannter Nächte, ohne personenbezogene Daten oder Puls. Server in Belgien.',
                  es: 'Número de instalaciones y noches detectadas, sin datos personales ni pulso. Servidor en Bélgica.',
                ),
                value: settings.anonymousTelemetryEnabled,
                onChanged: notifier.setAnonymousTelemetryEnabled,
              ),
              const SizedBox(height: 4),
              _LinkRow(
                icon: Icons.policy_outlined,
                color: OledColors.calmTeal,
                label: s.tr(
                  fr: 'Ce que SleepStop fait de tes données',
                  nl: 'Wat SleepStop met je gegevens doet',
                  de: 'Was SleepStop mit deinen Daten macht',
                  es: 'Qué hace SleepStop con tus datos',
                ),
                onTap: () => PrivacySheet.show(context),
              ),
              _LinkRow(
                icon: Icons.delete_outline_rounded,
                color: OledColors.mutedRose,
                label: s.tr(
                  fr: 'Effacer mes données locales',
                  nl: 'Mijn lokale gegevens wissen',
                  de: 'Lokale Daten löschen',
                  es: 'Borrar mis datos locales',
                ),
                onTap: () => _confirmErase(context, ref, s),
              ),
            ],
          ),

          // ------------------------------------------------------------------
          // 5. About
          // ------------------------------------------------------------------
          _Section(
            icon: Icons.info_outline_rounded,
            accent: OledColors.textSecondary,
            title: s.tr(
              fr: 'À propos',
              nl: 'Over',
              de: 'Über',
              es: 'Acerca de',
            ),
            children: [
              _LinkRow(
                icon: settings.isProUnlocked
                    ? Icons.verified_rounded
                    : Icons.workspace_premium_rounded,
                color: OledColors.gold,
                label: settings.isProUnlocked
                    ? s.proActiveBadge
                    : s.unlockProTitle,
                onTap: () => ProUnlockSheet.show(context),
              ),
              _LinkRow(
                icon: Icons.replay_rounded,
                color: OledColors.textSecondary,
                label: s.replayOnboarding,
                onTap: () async {
                  await notifier.replayOnboarding();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
              _LinkRow(
                icon: Icons.public_rounded,
                color: OledColors.textSecondary,
                label: 'sleepstop.eu',
                onTap: () => _copy(context, kWebsiteUrl, s),
              ),
              _LinkRow(
                icon: Icons.mail_outline_rounded,
                color: OledColors.textSecondary,
                label: kSupportEmail,
                onTap: () => _copy(context, kSupportEmail, s),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'SleepStop $kAppVersionLabel • Android',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: OledColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text, AppStrings s) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.tr(
            fr: 'Copié : $text',
            nl: 'Gekopieerd: $text',
            de: 'Kopiert: $text',
            es: 'Copiado: $text',
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: OledColors.elevatedSurface,
      ),
    );
  }

  Future<void> _confirmErase(
    BuildContext context,
    WidgetRef ref,
    AppStrings s,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OledColors.elevatedSurface,
        title: Text(
          s.tr(
            fr: 'Effacer toutes les données ?',
            nl: 'Alle gegevens wissen?',
            de: 'Alle Daten löschen?',
            es: '¿Borrar todos los datos?',
          ),
          style: const TextStyle(color: OledColors.textPrimary, fontSize: 17),
        ),
        content: Text(
          s.tr(
            fr: 'Historique des nuits, pouls appris et réglages. Ton accès Pro et ton essai sont conservés.',
            nl: 'Nachtgeschiedenis, geleerde hartslag en instellingen. Je Pro-toegang en proefperiode blijven behouden.',
            de: 'Nachtverlauf, gelernter Puls und Einstellungen. Pro-Zugang und Testphase bleiben erhalten.',
            es: 'Historial de noches, pulso aprendido y ajustes. Tu acceso Pro y tu prueba se conservan.',
          ),
          style: const TextStyle(color: OledColors.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.permNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: OledColors.mutedRose,
              foregroundColor: Colors.white,
            ),
            child: Text(
              s.tr(fr: 'Effacer', nl: 'Wissen', de: 'Löschen', es: 'Borrar'),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(sessionLogsProvider.notifier).clearAllLogs();
    await ref.read(settingsProvider.notifier).resetAllSettingsAndLearnedData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.tr(
            fr: 'Données locales effacées.',
            nl: 'Lokale gegevens gewist.',
            de: 'Lokale Daten gelöscht.',
            es: 'Datos locales borrados.',
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: OledColors.elevatedSurface,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.accent,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: OledColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: OledColors.subtleBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String text;
  final Color color;
  const _SubHeader(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: OledColors.textPrimary,
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String body;
  final String? footer;
  const _InfoBox({required this.title, required this.body, this.footer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OledColors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OledColors.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: OledColors.warmAmber,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: OledColors.textSecondary,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 6),
            Text(
              footer!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: OledColors.calmTeal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RadioRow({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? OledColors.warmAmber.withValues(alpha: 0.12)
                : OledColors.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? OledColors.warmAmber : OledColors.subtleBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 18,
                color: selected ? OledColors.warmAmber : OledColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? OledColors.warmAmber
                            : OledColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: OledColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OledColors.textPrimary,
                ),
              ),
            ),
            Text(
              valueText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: OledColors.warmAmber,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: OledColors.warmAmber,
            inactiveTrackColor: OledColors.subtleBorder,
            thumbColor: OledColors.warmAmber,
            overlayColor: OledColors.warmAmber.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: OledColors.warmAmber,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: OledColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          color: OledColors.textSecondary,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _LinkRow({
    required this.icon,
    required this.color,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: OledColors.textPrimary,
                ),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: OledColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: OledColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
