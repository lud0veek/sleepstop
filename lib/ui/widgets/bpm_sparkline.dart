import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/oled_theme.dart';

/// Minimal heart-rate curve used both live on the dashboard and in the
/// history. Optionally draws a dashed horizontal line at [thresholdBpm].
class BpmSparkline extends StatelessWidget {
  final List<int> samples;
  final int? thresholdBpm;
  final double height;
  final Color color;

  const BpmSparkline({
    super.key,
    required this.samples,
    this.thresholdBpm,
    this.height = 36,
    this.color = OledColors.warmAmber,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _BpmSparklinePainter(
          samples: samples,
          thresholdBpm: thresholdBpm,
          color: color,
        ),
      ),
    );
  }
}

class _BpmSparklinePainter extends CustomPainter {
  final List<int> samples;
  final int? thresholdBpm;
  final Color color;

  const _BpmSparklinePainter({
    required this.samples,
    required this.thresholdBpm,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    var minBpm = samples.reduce(math.min).toDouble();
    var maxBpm = samples.reduce(math.max).toDouble();
    final t = thresholdBpm;
    if (t != null) {
      minBpm = math.min(minBpm, t.toDouble());
      maxBpm = math.max(maxBpm, t.toDouble());
    }
    minBpm -= 2;
    maxBpm += 2;
    final range = (maxBpm - minBpm).clamp(4.0, 100.0);

    double yFor(num bpm) => size.height - ((bpm - minBpm) / range) * size.height;

    // Soft area fill under the curve.
    final line = Path();
    for (int i = 0; i < samples.length; i++) {
      final x = (i / (samples.length - 1)) * size.width;
      final y = yFor(samples[i]);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    // Threshold: dashed line.
    if (t != null) {
      final y = yFor(t);
      final dash = Paint()
        ..color = OledColors.calmTeal.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), dash);
        x += 8;
      }
    }

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Current point.
    final lastX = size.width;
    final lastY = yFor(samples.last);
    canvas.drawCircle(Offset(lastX, lastY), 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BpmSparklinePainter old) =>
      old.samples != samples || old.thresholdBpm != thresholdBpm || old.color != color;
}
