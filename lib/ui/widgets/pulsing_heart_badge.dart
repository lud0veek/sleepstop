import 'package:flutter/material.dart';
import '../theme/oled_theme.dart';

class PulsingHeartBadge extends StatefulWidget {
  final int? bpm;
  final bool isMonitoring;
  final String liveLabel;
  final String waitingLabel;

  const PulsingHeartBadge({
    super.key,
    required this.bpm,
    required this.isMonitoring,
    this.liveLabel = 'Direct BLE 0x2A37',
    this.waitingLabel = 'En attente FC',
  });

  @override
  State<PulsingHeartBadge> createState() => _PulsingHeartBadgeState();
}

class _PulsingHeartBadgeState extends State<PulsingHeartBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationForBpm(widget.bpm),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.94,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isMonitoring) {
      _controller.repeat(reverse: true);
    }
  }

  Duration _durationForBpm(int? bpm) {
    if (bpm == null || bpm <= 0) {
      return const Duration(milliseconds: 950);
    }
    final cycleMs = (60000 / bpm.clamp(35, 180) / 2).round();
    return Duration(milliseconds: cycleMs.clamp(250, 1200));
  }

  @override
  void didUpdateWidget(covariant PulsingHeartBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bpm != oldWidget.bpm) {
      _controller.duration = _durationForBpm(widget.bpm);
      if (widget.isMonitoring && !_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }
    if (widget.isMonitoring != oldWidget.isMonitoring) {
      if (widget.isMonitoring) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isMonitoring && widget.bpm != null;
    final heartColor = active ? OledColors.deepOrange : OledColors.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: heartColor.withValues(alpha: 0.14),
              border: Border.all(
                color: heartColor.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Icon(Icons.favorite_rounded, color: heartColor, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      widget.bpm != null ? '${widget.bpm}' : '--',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? OledColors.textPrimary
                            : OledColors.textMuted,
                        letterSpacing: -1,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'BPM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: OledColors.warmAmber,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                active ? widget.liveLabel : widget.waitingLabel,
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
      ],
    );
  }
}
