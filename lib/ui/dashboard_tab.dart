import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../models/active_session_state.dart';
import '../models/sleep_settings.dart';
import '../providers/settings_provider.dart';
import '../services/permission_service.dart';
import '../providers/sleep_session_provider.dart';
import 'privacy_sheet.dart';
import 'permission_primer_sheet.dart';
import 'pro_unlock_sheet.dart';
import 'settings_bottom_sheet.dart';
import 'target_apps_sheet.dart';
import 'theme/oled_theme.dart';
import 'watch_guide_sheet.dart';
import 'widgets/pulsing_heart_badge.dart';

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sleepSessionProvider);
    final settings = ref.watch(settingsProvider);
    final s = ref.watch(appStringsProvider);
    final notifier = ref.read(sleepSessionProvider.notifier);

    final remainingTrialNights = settings.remainingTrialNights;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _buildProTrialBanner(
          context: context,
          settings: settings,
          remainingTrialNights: remainingTrialNights,
          s: s,
        ),
        const SizedBox(height: 12),

        _buildModeSelector(
          context: context,
          session: session,
          onSelect: notifier.selectMode,
          s: s,
        ),
        const SizedBox(height: 16),

        _buildPrimarySessionButton(
          context: context,
          ref: ref,
          session: session,
          settings: settings,
          remainingTrialNights: remainingTrialNights,
          notifier: notifier,
          s: s,
        ),
        const SizedBox(height: 18),

        _buildLiveStatusCard(
          context: context,
          ref: ref,
          session: session,
          settings: settings,
          notifier: notifier,
          s: s,
        ),
        const SizedBox(height: 14),

        _buildThresholdQuickCard(
          context: context,
          session: session,
          settings: settings,
          s: s,
        ),
        const SizedBox(height: 14),

        _buildTargetAppsAndGuideRow(
          context: context,
          settings: settings,
          notifier: notifier,
          s: s,
        ),
        const SizedBox(height: 14),

        _buildMediaControllerBar(context: context, ref: ref, s: s),
      ],
    );
  }

  Widget _buildProTrialBanner({
    required BuildContext context,
    required SleepSettings settings,
    required int remainingTrialNights,
    required AppStrings s,
  }) {
    final isPro = settings.isProUnlocked;
    final color = isPro ? OledColors.calmTeal : OledColors.warmAmber;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => ProUnlockSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(
              isPro
                  ? Icons.verified_rounded
                  : Icons.workspace_premium_rounded,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isPro
                    ? s.proActiveBadge
                    : s.trialBadgeText(remainingTrialNights),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: OledColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetAppsAndGuideRow({
    required BuildContext context,
    required SleepSettings settings,
    required SleepSessionNotifier notifier,
    required AppStrings s,
  }) {
    final appNames = settings.targetAppsToClose.values.toList();
    final appsSummary = appNames.isEmpty
        ? s.noAppSelected
        : appNames.take(4).join(', ') +
              (appNames.length > 4 ? ' +${appNames.length - 4}' : '');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: OledColors.cardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OledColors.subtleBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.apps_outage_rounded,
                color: OledColors.softIndigo,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.appsToCloseTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: OledColors.textPrimary,
                      ),
                    ),
                    Text(
                      settings.closeAppsOnSleep
                          ? appsSummary
                          : s.appsPausedOnlyTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: OledColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => TargetAppsSheet.show(context),
                child: Text(
                  s.configureButton,
                  style: const TextStyle(
                    color: OledColors.softIndigo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: OledColors.cardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OledColors.subtleBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.help_outline_rounded,
                color: OledColors.calmTeal,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.watchGuideBanner,
                  style: const TextStyle(
                    fontSize: 12,
                    color: OledColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => WatchGuideSheet.show(context),
                child: Text(
                  s.guideButton,
                  style: const TextStyle(
                    color: OledColors.calmTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: OledColors.cardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OledColors.subtleBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.dashboard_customize_rounded,
                color: OledColors.warmAmber,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.quickTileTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: OledColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.quickTileSubtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: OledColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  final status = await notifier.requestAddQuickTile();
                  if (!context.mounted) return;
                  final msg = switch (status) {
                    'ADDED' => s.quickTileAddedMsg,
                    'ALREADY_ADDED' => s.quickTileAlreadyMsg,
                    _ => s.quickTileManualMsg,
                  };
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: OledColors.elevatedSurface,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Text(
                  s.addButton,
                  style: const TextStyle(
                    color: OledColors.warmAmber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: OledColors.cardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OledColors.subtleBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: OledColors.calmTeal,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.tr(
                        fr: 'Confidentialité & RGPD (Belgique 🇧🇪)',
                        nl: 'Privacy & AVG / GDPR (België 🇧🇪)',
                        de: 'Datenschutz & DSGVO (Belgien 🇧🇪)',
                        es: 'Privacidad y RGPD (Bélgica 🇧🇪)',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: OledColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.tr(
                        fr: '100 % local pour le pouls • Loi belge du 30 juillet 2018 & APD',
                        nl: '100% lokaal voor hartslag • Belgische wet van 30 juli 2018 & GBA',
                        de: '100 % lokal für Herzfrequenz • Belgisches Gesetz & APD/GBA',
                        es: '100 % local para el pulso • Ley belga del 30 de julio de 2018 y APD',
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: OledColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => PrivacySheet.show(context),
                child: Text(
                  s.tr(
                    fr: 'Infos RGPD',
                    nl: 'AVG-info',
                    de: 'DSGVO-Info',
                    es: 'Info RGPD',
                  ),
                  style: const TextStyle(
                    color: OledColors.calmTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector({
    required BuildContext context,
    required ActiveSessionState session,
    required void Function(DetectionMode) onSelect,
    required AppStrings s,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: OledColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OledColors.subtleBorder),
      ),
      child: SegmentedButton<DetectionMode>(
        segments: [
          ButtonSegment<DetectionMode>(
            value: DetectionMode.watchBle,
            icon: const Icon(Icons.watch_rounded, size: 18),
            label: Text(
              s.modeWatchBle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ButtonSegment<DetectionMode>(
            value: DetectionMode.phoneFadeShake,
            icon: const Icon(Icons.vibration_rounded, size: 18),
            label: Text(
              s.modePhoneShake,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        selected: {session.activeMode},
        showSelectedIcon: false,
        onSelectionChanged: session.isRunning
            ? null
            : (selection) {
                if (selection.isNotEmpty) {
                  onSelect(selection.first);
                }
              },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return OledColors.warmAmber.withValues(alpha: 0.16);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return OledColors.warmAmber;
            }
            return OledColors.textSecondary;
          }),
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimarySessionButton({
    required BuildContext context,
    required WidgetRef ref,
    required ActiveSessionState session,
    required SleepSettings settings,
    required int remainingTrialNights,
    required SleepSessionNotifier notifier,
    required AppStrings s,
  }) {
    final isRunning = session.isRunning;
    final accentColor = isRunning
        ? OledColors.deepOrange
        : OledColors.warmAmber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: isRunning ? s.stopSession : s.startSleepSession,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: () async {
                if (isRunning) {
                  notifier.stopSession();
                } else if (!settings.isProUnlocked &&
                    remainingTrialNights <= 0) {
                  ProUnlockSheet.show(context);
                } else {
                  if (!settings.onboardingPermissionsShown) {
                    final proceed = await PermissionPrimerSheet.show(context);
                    if (!proceed) return;
                    await ref
                        .read(settingsProvider.notifier)
                        .markOnboardingPermissionsShown();
                    await PermissionService.instance
                        .requestAllRequiredPermissions();
                  }
                  notifier.startSession();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: accentColor.withValues(alpha: isRunning ? 0.14 : 0.18),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.2),
                      ),
                      child: Icon(
                        isRunning ? Icons.stop_rounded : Icons.bedtime_rounded,
                        size: 30,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isRunning ? s.stopSession : s.startSleepSession,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isRunning
                          ? s.stopSubtitle
                          : (session.activeMode == DetectionMode.watchBle
                                ? s.startSubtitleWatch
                                : s.startSubtitlePhone),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: OledColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!isRunning && session.activeMode == DetectionMode.watchBle) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => notifier.startSession(simulateBleWatch: true),
              icon: const Icon(
                Icons.science_outlined,
                size: 16,
                color: OledColors.softIndigo,
              ),
              label: Text(
                s.simulateWatchBtn,
                style: const TextStyle(
                  fontSize: 12,
                  color: OledColors.softIndigo,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLiveStatusCard({
    required BuildContext context,
    required WidgetRef ref,
    required ActiveSessionState session,
    required SleepSettings settings,
    required SleepSessionNotifier notifier,
    required AppStrings s,
  }) {
    final isWatchMode = session.activeMode == DetectionMode.watchBle;
    final isSmart =
        settings.biometricTriggerMode == BiometricTriggerMode.smartAdaptive;
    final stateBadgeColor = switch (session.phase) {
      SessionPhase.fadingAudio => OledColors.deepOrange,
      SessionPhase.hrDropping => OledColors.warmAmber,
      SessionPhase.monitoring ||
      SessionPhase.calibratingBaseline => OledColors.calmTeal,
      SessionPhase.pausedCompleted => OledColors.softIndigo,
      SessionPhase.error => OledColors.mutedRose,
      _ => OledColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OledColors.cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: session.isFading
              ? OledColors.deepOrange.withValues(alpha: 0.6)
              : OledColors.subtleBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: stateBadgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: stateBadgeColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: stateBadgeColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            s.localizedPhaseStatus(session),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: stateBadgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    s.elapsedLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: OledColors.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    _formatDuration(session.elapsedSeconds),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: OledColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isWatchMode) ...[
            Row(
              children: [
                const Icon(
                  Icons.bluetooth_connected_rounded,
                  size: 16,
                  color: OledColors.softIndigo,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.connectedWatchName ??
                        settings.savedWatchName ??
                        s.noWatchConnected,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: OledColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: PulsingHeartBadge(
                    bpm: session.currentBpm,
                    isMonitoring: session.isRunning,
                    liveLabel: s.liveBleLabel,
                    waitingLabel: s.waitingForHr,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: OledColors.elevatedSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: OledColors.subtleBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isSmart ? s.adaptiveTargetLabel : s.thresholdLabel,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: OledColors.textMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '≤ ${session.effectiveThresholdBpm ?? settings.sleepBpmThreshold} BPM',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: OledColors.warmAmber,
                        ),
                      ),
                      if (session.baselineBpm != null)
                        Text(
                          s.awakeBaselineText(
                            session.baselineBpm!.toStringAsFixed(0),
                          ),
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

            if (session.isRunning) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: OledColors.elevatedSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: OledColors.subtleBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.waves_rounded,
                            size: 16,
                            color: OledColors.calmTeal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.hrStabilityTitle,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: OledColors.textMuted,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                Text(
                                  session.bpmStabilityStdDev != null
                                      ? '±${session.bpmStabilityStdDev!.toStringAsFixed(1)} BPM (${session.bpmStabilityStdDev! <= 1.8 ? s.calmPlateauLabel : s.activeMovementLabel})'
                                      : s.collectingWindowLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: OledColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (session.hrvRmssdMs != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: OledColors.elevatedSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: OledColors.subtleBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'HRV',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: OledColors.textMuted,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            '${session.hrvRmssdMs!.toStringAsFixed(0)} ms',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: OledColors.softIndigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],

            if (session.isRunning && !session.isFading) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isSmart
                          ? s.sleepConfidenceLabel
                          : s.confirmationWindowLabel(
                              settings.confirmationDurationMinutes,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: OledColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(session.lowHrProgress * 100).round()}% (${_formatDuration(session.consecutiveLowHrSeconds)} / ${_formatDuration(session.requiredLowHrSeconds)})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OledColors.warmAmber,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: session.lowHrProgress,
                  minHeight: 7,
                  backgroundColor: OledColors.elevatedSurface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    OledColors.warmAmber,
                  ),
                ),
              ),
            ],
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.nextSleepCheckLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: OledColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.isRunning
                            ? _formatDuration(
                                session.checkIntervalRemainingSeconds,
                              )
                            : '${settings.checkIntervalMinutes}:00',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: OledColors.warmAmber,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: OledColors.elevatedSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: OledColors.subtleBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        s.motionShakeLabel,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: OledColors.textMuted,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.lastShakeMagnitude.toStringAsFixed(2)} m/s²',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: OledColors.softIndigo,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        '≥ ${settings.shakeSensitivity.toStringAsFixed(1)} m/s²',
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
          ],

          if (session.isFading) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OledColors.deepOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: OledColors.deepOrange.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.fadingVolumeLabel(session.fadeRemainingSeconds),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: OledColors.deepOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Vol: ${session.currentVolume ?? 0}/${session.maxVolume ?? 15}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: OledColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: session.fadeProgress,
                      minHeight: 7,
                      backgroundColor: OledColors.trueBlack,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        OledColors.deepOrange,
                      ),
                    ),
                  ),
                  if (session.activeMode == DetectionMode.phoneFadeShake) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: notifier.triggerManualWakeReset,
                        icon: const Icon(Icons.pan_tool_alt_rounded, size: 18),
                        label: Text(s.imAwakeRestoreBtn),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OledColors.warmAmber,
                          side: const BorderSide(color: OledColors.warmAmber),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          if (session.isRunning && !session.isFading) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (session.activeMode == DetectionMode.phoneFadeShake)
                  OutlinedButton.icon(
                    onPressed: notifier.triggerManualWakeReset,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(s.resetTimerBtn),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OledColors.textPrimary,
                      side: const BorderSide(color: OledColors.subtleBorder),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: notifier.triggerFadeNowForTesting,
                  icon: const Icon(Icons.trending_down_rounded, size: 16),
                  label: Text(s.testFadeNowBtn(isWatchMode ? 10 : 60)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OledColors.warmAmber,
                    side: BorderSide(
                      color: OledColors.warmAmber.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThresholdQuickCard({
    required BuildContext context,
    required ActiveSessionState session,
    required SleepSettings settings,
    required AppStrings s,
  }) {
    final isWatch = session.activeMode == DetectionMode.watchBle;
    final isSmart =
        settings.biometricTriggerMode == BiometricTriggerMode.smartAdaptive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: OledColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OledColors.subtleBorder),
      ),
      child: Row(
        children: [
          Icon(
            isWatch ? Icons.auto_awesome_rounded : Icons.timer_outlined,
            color: OledColors.warmAmber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isWatch
                  ? (isSmart
                        ? s.smartAdaptiveSummary(settings.adaptiveSensitivity)
                        : s.manualBpmSummary(
                            settings.sleepBpmThreshold,
                            settings.confirmationDurationMinutes,
                          ))
                  : s.phoneIntervalSummary(
                      settings.checkIntervalMinutes,
                      settings.shakeSensitivity.toStringAsFixed(1),
                    ),
              style: const TextStyle(
                fontSize: 12,
                color: OledColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => SettingsBottomSheet.show(context),
            child: Text(
              s.configureButton,
              style: const TextStyle(
                color: OledColors.warmAmber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaControllerBar({
    required BuildContext context,
    required WidgetRef ref,
    required AppStrings s,
  }) {
    final mediaService = ref.read(mediaControlServiceProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OledColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OledColors.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.universalControllerTitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: OledColors.textMuted,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.universalControllerDesc,
            style: const TextStyle(
              fontSize: 12,
              color: OledColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await mediaService.rewindMedia();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(s.dispatchedRewindMsg),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.fast_rewind_rounded, size: 17),
                  label: Text(
                    s.rewindBtn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OledColors.textPrimary,
                    side: const BorderSide(color: OledColors.subtleBorder),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await mediaService.pauseMedia();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(s.dispatchedPauseMsg),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 17,
                  ),
                  label: Text(
                    s.pauseMediaBtn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OledColors.warmAmber,
                    side: BorderSide(
                      color: OledColors.warmAmber.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
