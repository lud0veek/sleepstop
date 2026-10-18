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
import 'sleep_actions_screen.dart';
import 'theme/oled_theme.dart';
import 'watch_guide_sheet.dart';
import 'widgets/settings_blocks.dart';
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
          SettingsSection(
            icon: Icons.monitor_heart_outlined,
            accent: OledColors.warmAmber,
            title: s.tr(
              fr: 'Détection du sommeil',
              nl: 'Slaapdetectie',
              de: 'Schlaferkennung',
              es: 'Detección del sueño',
            ),
            children: [
              SettingsLabel(
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
              SettingsSubHeader(s.settingsWatchSection, color: OledColors.warmAmber),
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
                SettingsInfoBox(
                  title: s.howSmartWorksTitle,
                  body: s.howSmartWorksBody,
                  footer: settings.learnedSleepingBpm != null
                      ? s.learnedSleepHrText(
                          settings.learnedSleepingBpm!.toStringAsFixed(0),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                SettingsLabel(s.sensitivityProfileTitle),
                const SizedBox(height: 8),
                ...AdaptiveSensitivity.values.map(
                  (preset) => SettingsRadioRow(
                    selected: settings.adaptiveSensitivity == preset,
                    title: s.sensitivityTitle(preset),
                    subtitle: s.sensitivityDesc(preset),
                    onTap: () => notifier.setAdaptiveSensitivity(preset),
                  ),
                ),
              ] else ...[
                SettingsSliderRow(
                  label: s.fixedBpmSliderLabel,
                  valueText: '${settings.sleepBpmThreshold} BPM',
                  value: settings.sleepBpmThreshold.toDouble(),
                  min: 40,
                  max: 85,
                  divisions: 45,
                  onChanged: (v) => notifier.setSleepBpmThreshold(v.round()),
                ),
                const SizedBox(height: 6),
                SettingsSliderRow(
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
              SettingsLinkRow(
                icon: Icons.help_outline_rounded,
                color: OledColors.calmTeal,
                label: s.watchGuideTooltip,
                onTap: () => WatchGuideSheet.show(context),
              ),
              const SizedBox(height: 18),

              // Phone settings
              SettingsSubHeader(s.settingsPhoneSection, color: OledColors.softIndigo),
              const SizedBox(height: 10),
              SettingsSliderRow(
                label: s.timerIntervalSliderLabel,
                valueText: '${settings.checkIntervalMinutes} min',
                value: settings.checkIntervalMinutes.toDouble(),
                min: 1,
                max: 60,
                divisions: 59,
                onChanged: (v) => notifier.setCheckIntervalMinutes(v.round()),
              ),
              const SizedBox(height: 6),
              SettingsSliderRow(
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
          SettingsSection(
            icon: Icons.bedtime_rounded,
            accent: OledColors.softIndigo,
            title: s.tr(
              fr: 'À l\'endormissement',
              nl: 'Bij het inslapen',
              de: 'Beim Einschlafen',
              es: 'Al dormirse',
            ),
            children: [
              SettingsToggle(
                title: s.autoRewindTitle,
                subtitle: s.autoRewindSubtitle,
                value: settings.rewindOnPause,
                onChanged: notifier.setRewindOnPause,
              ),
              SettingsToggle(
                title: s.tr(
                  fr: 'Écran noir et sortie du plein écran',
                  nl: 'Zwart scherm en volledig scherm verlaten',
                  de: 'Schwarzer Bildschirm und Vollbild beenden',
                  es: 'Pantalla negra y salir de pantalla completa',
                ),
                subtitle: s.tr(
                  fr: 'Voile noir sur la vidéo pendant « Encore réveillé ? », puis retour à l\'accueil pour que l\'écran s\'éteigne tout seul.',
                  nl: 'Zwart scherm over de video tijdens "Nog wakker?", daarna terug naar het startscherm zodat het scherm vanzelf uitgaat.',
                  de: 'Schwarzer Schleier über dem Video während „Noch wach?“, danach zurück zum Startbildschirm, damit das Display von selbst ausgeht.',
                  es: 'Velo negro sobre el vídeo durante «¿Aún despierto?», luego vuelta al inicio para que la pantalla se apague sola.',
                ),
                value: settings.returnToHomeOnSleep,
                onChanged: notifier.setReturnToHomeOnSleep,
              ),
              SettingsToggle(
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
              _OverlayPermissionRow(s: s),
              SettingsLinkRow(
                icon: Icons.auto_awesome_rounded,
                color: OledColors.gold,
                label: s.sleepActionsTitle,
                trailing: s.sleepActionsSummary(
                  settings.sleepActions.enabled
                      ? settings.sleepActions.activeCount
                      : 0,
                ),
                onTap: () => SleepActionsScreen.open(context),
              ),
              SettingsLinkRow(
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
          SettingsSection(
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
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => notifier.setLanguageCode(code),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? OledColors.warmAmber.withValues(alpha: 0.14)
                            : OledColors.elevatedSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? OledColors.warmAmber
                              : OledColors.subtleBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FlagIcon(code: code, width: 20, radius: 2),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.languageName(code),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? OledColors.warmAmber
                                  : OledColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ------------------------------------------------------------------
          // 4. Privacy
          // ------------------------------------------------------------------
          SettingsSection(
            icon: Icons.verified_user_outlined,
            accent: OledColors.calmTeal,
            title: s.tr(
              fr: 'Confidentialité',
              nl: 'Privacy',
              de: 'Datenschutz',
              es: 'Privacidad',
            ),
            children: [
              SettingsToggle(
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
              SettingsLinkRow(
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
              SettingsLinkRow(
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
          SettingsSection(
            icon: Icons.info_outline_rounded,
            accent: OledColors.textSecondary,
            title: s.tr(
              fr: 'À propos',
              nl: 'Over',
              de: 'Über',
              es: 'Acerca de',
            ),
            children: [
              SettingsLinkRow(
                icon: settings.isProUnlocked
                    ? Icons.verified_rounded
                    : Icons.workspace_premium_rounded,
                color: OledColors.gold,
                label: settings.isProUnlocked
                    ? s.proActiveBadge
                    : s.unlockProTitle,
                onTap: () => ProUnlockSheet.show(context),
              ),
              SettingsLinkRow(
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
              SettingsLinkRow(
                icon: Icons.public_rounded,
                color: OledColors.textSecondary,
                label: 'sleepstop.eu',
                onTap: () => _copy(context, kWebsiteUrl, s),
              ),
              SettingsLinkRow(
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

/// "Display over other apps" status + shortcut to the system toggle.
class _OverlayPermissionRow extends ConsumerStatefulWidget {
  final AppStrings s;
  const _OverlayPermissionRow({required this.s});

  @override
  ConsumerState<_OverlayPermissionRow> createState() =>
      _OverlayPermissionRowState();
}

class _OverlayPermissionRowState extends ConsumerState<_OverlayPermissionRow>
    with WidgetsBindingObserver {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final ok = await ref.read(mediaControlServiceProvider).canDrawOverlays();
    if (mounted) setState(() => _granted = ok);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final granted = _granted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsLinkRow(
          icon: Icons.brightness_2_rounded,
          color: granted == true ? OledColors.calmTeal : OledColors.warmAmber,
          label: s.overlayPermTitle,
          trailing: granted == null
              ? null
              : (granted ? s.overlayPermGranted : s.overlayPermMissing),
          onTap: () =>
              ref.read(mediaControlServiceProvider).openOverlayPermissionSettings(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(33, 0, 8, 10),
          child: Text(
            s.overlayPermBody,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: OledColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
