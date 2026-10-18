import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/sleep_session_log.dart';
import '../models/sleep_settings.dart';
import '../providers/session_logs_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sleep_session_provider.dart';
import 'theme/oled_theme.dart';

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(sessionLogsProvider);
    final s = ref.watch(appStringsProvider);

    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: OledColors.cardSurface,
                  border: Border.all(color: OledColors.subtleBorder),
                ),
                child: const Icon(
                  Icons.history_toggle_off_rounded,
                  color: OledColors.warmAmber,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.noSessionsYet,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: OledColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.noSessionsDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: OledColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final log = logs[index];
        return _SessionHistoryCard(log: log, isLatest: index == 0);
      },
    );
  }
}

class _SessionHistoryCard extends ConsumerWidget {
  final SleepSessionLog log;
  final bool isLatest;

  const _SessionHistoryCard({required this.log, required this.isLatest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('EEE, MMM d');
    final startStr = timeFormat.format(log.startTime);
    final asleepStr = timeFormat.format(log.asleepTime);
    final dateStr = dateFormat.format(log.startTime);

    final hasAppInfo =
        (log.mediaAppName != null && log.mediaAppName!.isNotEmpty) ||
        log.closedApps.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OledColors.cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLatest
              ? OledColors.warmAmber.withValues(alpha: 0.5)
              : OledColors.subtleBorder,
          width: isLatest ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isLatest) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: OledColors.warmAmber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.tabTonight.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: OledColors.warmAmber,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  dateStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OledColors.textSecondary,
                  ),
                ),
              ),
              Icon(
                log.mode == DetectionMode.watchBle
                    ? Icons.watch_rounded
                    : Icons.vibration_rounded,
                size: 15,
                color: OledColors.softIndigo,
              ),
              const SizedBox(width: 5),
              Text(
                log.mode == DetectionMode.watchBle
                    ? s.modeWatchBle
                    : s.modePhoneShake,
                style: const TextStyle(
                  fontSize: 12,
                  color: OledColors.softIndigo,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {
                  ref
                      .read(sessionLogsProvider.notifier)
                      .deleteSessionLog(log.id);
                },
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: OledColors.textMuted,
                ),
                visualDensity: VisualDensity.compact,
                tooltip: s.clearHistoryBtn,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Prominent Actual Listening Time Banner (Rewind Helper)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: OledColors.warmAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: OledColors.warmAmber.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.replay_rounded,
                  color: OledColors.warmAmber,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.listenedForPrefix.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: OledColors.warmAmber,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        log.formattedListeningDuration,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: OledColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(mediaControlServiceProvider).rewindMedia();
                  },
                  icon: const Icon(Icons.fast_rewind_rounded, size: 15),
                  label: Text(s.rewindBtn),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OledColors.warmAmber,
                    side: BorderSide(
                      color: OledColors.warmAmber.withValues(alpha: 0.5),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),

          // Paused / Closed App & Media Title Banner
          if (hasAppInfo ||
              (log.mediaTitle != null && log.mediaTitle!.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: OledColors.elevatedSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: OledColors.subtleBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.apps_outage_rounded,
                    size: 18,
                    color: OledColors.softIndigo,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.mediaAppName != null &&
                                  log.mediaAppName!.isNotEmpty
                              ? '${s.closedPrefix} : ${log.mediaAppName}'
                              : '${s.closedPrefix} : ${log.closedApps.join(", ")}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: OledColors.textPrimary,
                          ),
                        ),
                        if (log.mediaTitle != null &&
                            log.mediaTitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '« ${log.mediaTitle} »',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: OledColors.warmAmber,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: s.startedLabel,
                  value: startStr,
                  icon: Icons.play_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: s.fellAsleepLabel,
                  value: asleepStr,
                  icon: Icons.pause_circle_outline_rounded,
                ),
              ),
            ],
          ),

          // Heart Rate Sparkline Curve if recorded
          if (log.bpmTimeline.length >= 2) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: OledColors.elevatedSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: OledColors.subtleBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.hrSleepCurveTitle,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: OledColors.textMuted,
                          letterSpacing: 0.7,
                        ),
                      ),
                      Text(
                        '${log.bpmTimeline.first} BPM → ${log.bpmTimeline.last} BPM',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: OledColors.calmTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _BpmSparklinePainter(samples: log.bpmTimeline),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 16,
                color: OledColors.deepOrange,
              ),
              const SizedBox(width: 6),
              Text(
                s.triggerPrefix,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OledColors.textSecondary,
                ),
              ),
              Expanded(
                child: Text(
                  log.triggerReason,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OledColors.textPrimary,
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

class _BpmSparklinePainter extends CustomPainter {
  final List<int> samples;

  const _BpmSparklinePainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    final minBpm = samples.reduce(math.min).toDouble() - 2;
    final maxBpm = samples.reduce(math.max).toDouble() + 2;
    final range = (maxBpm - minBpm).clamp(4.0, 100.0);

    final path = Path();
    for (int i = 0; i < samples.length; i++) {
      final x = (i / (samples.length - 1)) * size.width;
      final normalized = (samples[i] - minBpm) / range;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = OledColors.warmAmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _BpmSparklinePainter oldDelegate) =>
      oldDelegate.samples != samples;
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OledColors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OledColors.subtleBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: OledColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: OledColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: OledColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
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
