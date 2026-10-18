import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'theme/oled_theme.dart';

/// Shown once, right before the very first sleep session, to explain which
/// Android permissions are about to be requested and why. Returns `true` when
/// the user taps "Continue" (the caller then triggers the system prompts).
class PermissionPrimerSheet extends ConsumerWidget {
  const PermissionPrimerSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OledColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const PermissionPrimerSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: OledColors.subtleBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              s.permTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: OledColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.permIntro,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: OledColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _PermissionRow(
              icon: Icons.bluetooth_searching_rounded,
              accent: OledColors.softIndigo,
              title: s.permBluetoothTitle,
              body: s.permBluetoothBody,
            ),
            const SizedBox(height: 12),
            _PermissionRow(
              icon: Icons.notifications_active_outlined,
              accent: OledColors.warmAmber,
              title: s.permNotifTitle,
              body: s.permNotifBody,
            ),
            const SizedBox(height: 12),
            _PermissionRow(
              icon: Icons.battery_saver_rounded,
              accent: OledColors.calmTeal,
              title: s.permBatteryTitle,
              body: s.permBatteryBody,
            ),
            const SizedBox(height: 12),
            _PermissionRow(
              icon: Icons.brightness_2_rounded,
              accent: OledColors.textSecondary,
              title: '${s.overlayPermTitle} • ${s.overlayPermOptional}',
              body: s.overlayPermBody,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: OledColors.warmAmber,
                foregroundColor: OledColors.trueBlack,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                s.permContinue,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                s.permNotNow,
                style: const TextStyle(
                  fontSize: 13,
                  color: OledColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String body;

  const _PermissionRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OledColors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OledColors.subtleBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: OledColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: OledColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
