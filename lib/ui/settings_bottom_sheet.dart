import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sleep_settings.dart';
import '../providers/settings_provider.dart';
import 'theme/oled_theme.dart';

class SettingsBottomSheet extends ConsumerWidget {
  const SettingsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OledColors.cardSurface,
      builder: (_) => const SettingsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isSmart =
        settings.biometricTriggerMode == BiometricTriggerMode.smartAdaptive;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: OledColors.subtleBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sleep Detection Settings',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: OledColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: OledColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Section 1: Watch (BLE) Biometric Trigger Mode
            const Text(
              'SMARTWATCH BIOMETRIC ALGORITHM (GARMIN / BLE)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: OledColors.warmAmber,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: SegmentedButton<BiometricTriggerMode>(
                segments: const [
                  ButtonSegment<BiometricTriggerMode>(
                    value: BiometricTriggerMode.smartAdaptive,
                    icon: Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(
                      'Smart Adaptive',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ButtonSegment<BiometricTriggerMode>(
                    value: BiometricTriggerMode.manualBpm,
                    icon: Icon(Icons.tune_rounded, size: 16),
                    label: Text(
                      'Manual BPM',
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
            ),
            const SizedBox(height: 14),

            if (isSmart) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: OledColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: OledColors.subtleBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How Smart Adaptive Works (Firstbeat Style)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: OledColors.warmAmber,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '1. Measures your personal Awake Baseline during the first 90s.\n'
                      '2. Adapts automatically whether your starting HR is high (72 BPM) or already low in bed (54 BPM).\n'
                      '3. Confirms sleep when HR drops AND enters a flat parasympathetic plateau (±1.8 BPM stability).',
                      style: TextStyle(
                        fontSize: 12,
                        color: OledColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (settings.learnedSleepingBpm != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Learned Personal Sleep HR: ~${settings.learnedSleepingBpm!.toStringAsFixed(0)} BPM',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: OledColors.calmTeal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Sensitivity Profile',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OledColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...AdaptiveSensitivity.values.map((preset) {
                final selected = settings.adaptiveSensitivity == preset;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => notifier.setAdaptiveSensitivity(preset),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
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
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 18,
                            color: selected
                                ? OledColors.warmAmber
                                : OledColors.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preset.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? OledColors.warmAmber
                                        : OledColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  preset.description,
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
              }),
            ] else ...[
              _SliderRow(
                label: 'Fixed Sleep BPM Threshold',
                valueText: '${settings.sleepBpmThreshold} BPM',
                value: settings.sleepBpmThreshold.toDouble(),
                min: 40,
                max: 85,
                divisions: 45,
                onChanged: (v) => notifier.setSleepBpmThreshold(v.round()),
              ),
              const SizedBox(height: 8),
              _SliderRow(
                label: 'Confirmation Duration',
                valueText: '${settings.confirmationDurationMinutes} min',
                value: settings.confirmationDurationMinutes.toDouble(),
                min: 1,
                max: 15,
                divisions: 14,
                onChanged: (v) =>
                    notifier.setConfirmationDurationMinutes(v.round()),
              ),
            ],

            const Divider(color: OledColors.subtleBorder, height: 32),

            // Section 2: Phone (Fade & Shake) Mode Settings
            const Text(
              'PHONE MODE (SMART FADE & SHAKE)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: OledColors.softIndigo,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 12),

            _SliderRow(
              label: 'Timer Check Interval',
              valueText: '${settings.checkIntervalMinutes} min',
              value: settings.checkIntervalMinutes.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              onChanged: (v) => notifier.setCheckIntervalMinutes(v.round()),
            ),
            const SizedBox(height: 8),

            _SliderRow(
              label: 'Shake Sensitivity (m/s²)',
              valueText: '${settings.shakeSensitivity.toStringAsFixed(1)} m/s²',
              value: settings.shakeSensitivity,
              min: 0.5,
              max: 5.0,
              divisions: 45,
              onChanged: notifier.setShakeSensitivity,
            ),

            const Divider(color: OledColors.subtleBorder, height: 32),

            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: OledColors.warmAmber,
              title: const Text(
                'Auto-Rewind Before Pausing',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: OledColors.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Dispatches KEYCODE_MEDIA_REWIND right before pausing media',
                style: TextStyle(fontSize: 12, color: OledColors.textSecondary),
              ),
              value: settings.rewindOnPause,
              onChanged: notifier.setRewindOnPause,
            ),
          ],
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
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: OledColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: OledColors.elevatedSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: OledColors.subtleBorder),
              ),
              child: Text(
                valueText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OledColors.warmAmber,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
